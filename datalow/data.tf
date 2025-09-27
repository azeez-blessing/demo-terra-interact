# Data sources
data "aws_caller_identity" "current" {}
data "aws_region" "current" {}
# Lambda deployment package
# Take the  process.py file from source,
# inject variable value for firehose stream name
#  Conpress it as zip file for lambda function deployment
#  store it in output path
data "archive_file" "cloudtrail_processor_zip" {
  type        = "zip"
  output_path = "${path.module}/cloudtrail_processor.zip"
  source {
    content = templatefile("${path.module}/processor.py", {
      firehose_stream_name = "${var.project_name}-to-splunk"  # it has been pass as env variable
      //Terraform looks for a placeholder inside processor.py like: ${firehose_stream_name}
    })
    filename = "lambda_function.py"
  }
}