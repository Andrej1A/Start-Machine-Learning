variable "aws_access_key" {
        description = "Access key to AWS console"
}
variable "aws_secret_key" {
        description = "Secret key to AWS console"
}
variable "aws_key_pair_name" {
        description = "Name of the key pair for AWS"
}
variable "ssh_public_key" {
        description = "Public ssh key for ssh-login"
}
variable "ssh_private_key_file_path" {
        description = "File path to the private key for ssh-login"
}
