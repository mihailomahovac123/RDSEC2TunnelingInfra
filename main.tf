terraform {
  required_providers {
    aws = {
      source = "hashicorp/aws"
      version = "5.60.0"
    }
  }

     backend "s3" {
        bucket="tfstatemihailo"
        key="terraform4.state"
        region = "eu-central-1"
      
    }


}

provider "aws" {
  # Configuration options
   region="eu-central-1"
}

resource "aws_iam_role" "ssm_access_role" {
  name="SSMAccessRole"
  assume_role_policy = jsonencode(


    {
    "Version": "2012-10-17",
    "Statement": [
        {
            "Effect": "Allow",
            "Action": [
                "sts:AssumeRole"
            ],
            "Principal": {
                "Service": [
                    "ec2.amazonaws.com"
                ]
            }
        }
    ]
}
)
}

resource "aws_iam_role_policy" "ssm_full_access_policy" {
    name="ssm_full_access_policy"
    role=aws_iam_role.ssm_access_role.id
    policy=jsonencode(
        {
    "Version": "2012-10-17",
    "Statement": [
        {
            "Effect": "Allow",
            "Action": [
                "ssm:DescribeAssociation",
                "ssm:GetDeployablePatchSnapshotForInstance",
                "ssm:GetDocument",
                "ssm:DescribeDocument",
                "ssm:GetManifest",
                "ssm:GetParameter",
                "ssm:GetParameters",
                "ssm:ListAssociations",
                "ssm:ListInstanceAssociations",
                "ssm:PutInventory",
                "ssm:PutComplianceItems",
                "ssm:PutConfigurePackageResult",
                "ssm:UpdateAssociationStatus",
                "ssm:UpdateInstanceAssociationStatus",
                "ssm:UpdateInstanceInformation"
            ],
            "Resource": "*"
        },
        {
            "Effect": "Allow",
            "Action": [
                "ssmmessages:CreateControlChannel",
                "ssmmessages:CreateDataChannel",
                "ssmmessages:OpenControlChannel",
                "ssmmessages:OpenDataChannel"
            ],
            "Resource": "*"
        },
        {
            "Effect": "Allow",
            "Action": [
                "ec2messages:AcknowledgeMessage",
                "ec2messages:DeleteMessage",
                "ec2messages:FailMessage",
                "ec2messages:GetEndpoint",
                "ec2messages:GetMessages",
                "ec2messages:SendReply"
            ],
            "Resource": "*"
        }
    ]
}
)
  
}



resource "aws_iam_instance_profile" "ssm_instance_profile" {
    name="ssm_instance_profile"
    role = aws_iam_role.ssm_access_role.name #OVDE SE DODAJE ROLE, NE POLICY. NA POLICY BLOK SE DODAJE ROLE. ROLE SE ISPISUJE U INSTANCE PROFILE ROLE
}



resource "aws_security_group" "ec2_ssm_agent_sg" {
    name = "ec2_ssm_agent_sg"
    vpc_id = "vpc-0769af89e3dff6849"

   ingress {
        from_port = 22
        to_port = 22
        protocol = "tcp"
        cidr_blocks = ["0.0.0.0/0"]
    }

    egress {
        from_port = 0
        to_port = 0
        protocol = "-1"
        cidr_blocks = ["0.0.0.0/0"]
    }
  
}



resource "aws_instance" "ec2_with_cw_agent" {
  ami="ami-0dd35f81b9eeeddb1"
  subnet_id = "subnet-0c988bbc1a2d11109"
  instance_type = "t2.micro"
  associate_public_ip_address = true
  key_name = "first_key"

  iam_instance_profile = aws_iam_instance_profile.ssm_instance_profile.name
  security_groups = [aws_security_group.ec2_ssm_agent_sg.id]

}
#inatall ssm agent on amazon linux 2: sudo yum install -y https://s3.amazonaws.com/ec2-downloads-windows/SSMAgent/latest/linux_amd64/amazon-ssm-agent.rpm
# sudo systemctl status amazon-ssm-agent



resource "aws_db_subnet_group" "subnet_group" {
  name       = "dbsubnetgroup1"
  subnet_ids = ["subnet-0c988bbc1a2d11109","subnet-0c43693d56d99314e"] // 2 subnets

  tags = {
    Name = "My DB subnet group"
  }
}


resource "aws_security_group" "db_sg" {
  name        = "db_sg_for_my_ec2"
  description = "Security group for my ec2 access to db"
 
  vpc_id = "vpc-0769af89e3dff6849"
  
  ingress {
    from_port   =  3306
    to_port     =  3306
    protocol    = "tcp" 
    security_groups = [ aws_security_group.ec2_ssm_agent_sg.id ]  
  }
 
}

resource "aws_db_instance" "rds_db" {
   allocated_storage = 20
  db_name              = "rdsdb1"
  engine               = "mysql"
  engine_version       = "8.0.35"
  instance_class       = "db.m5d.large"
  username             = "admin"
  password             = "admin12345"
  skip_final_snapshot = true  
  #publicly_accessible = false #ovo je default privatnost baze
  db_subnet_group_name = aws_db_subnet_group.subnet_group.name //!!!
  vpc_security_group_ids = [aws_security_group.db_sg.id]  
}
#baza je privatna i sme da joj pristupi samo nasa ec2 instanca sa konfigurisanim ssm agentom



