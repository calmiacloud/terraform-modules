data "archive_file" "file" {
	type = "zip"
	source_file = "./src/lambda_sgadminupdate/index.js"
	output_path = "./tmp/${var.name}.zip"

}

resource "aws_lambda_function" "this" {
	function_name = var.name
	role = var.role
	handler = "index.handler"
	runtime = "nodejs22.x"
	filename = data.archive_file.file.output_path
	source_code_hash = data.archive_file.file.output_base64sha256
	environment {
	  variables = var.environment
	}
}