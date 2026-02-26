#-----compute/main.tf-----
#==========================
provider "aws" {
  region = var.region
}

#Get Linux AMI ID using SSM Parameter endpoint
#==============================================
data "aws_ssm_parameter" "webserver-ami" {
  name = "/aws/service/ami-amazon-linux-latest/amzn2-ami-hvm-x86_64-gp2"
}

#Create key-pair for logging into EC2 
#======================================
resource "aws_key_pair" "aws-key" {
  key_name   = "ansible"
  public_key = file(var.ssh_key_public)
}


#Create and bootstrap Managed Node Servers
#===========================================
resource "aws_instance" "managed_node" {
  # Creates 3 identical aws ec2 instances
  count = 4

  instance_type               = "t3.micro"
  ami                         = data.aws_ssm_parameter.webserver-ami.value
  tags = {
  Name = "host_node_${count.index}"
  }
  key_name                    = aws_key_pair.aws-key.key_name
  associate_public_ip_address = true
  vpc_security_group_ids      = [var.security_group]
  subnet_id                   = var.subnets

}