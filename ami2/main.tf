resource "aws_image_builder_image_recipe" "example_recipe" {
  name        = "example-recipe"
  description = "Example Image Recipe"
  parent_image = "ami-0abcdef1234567890"  # Imagen base
  block_device_mappings {
    device_name = "/dev/sda1"
    ebs {
      volume_size = 30  # Tamaño del disco
      volume_type = "gp2"
    }
  }

  components {
    component {
      component_arn = "arn:aws:imagebuilder:eu-south-2:aws:component/amazon-linux-2/1.0.0"
    }
    # Aquí puedes añadir más componentes si es necesario
  }
}

resource "aws_image_builder_infrastructure_configuration" "example_infrastructure" {
  name                = "example-infrastructure"
  instance_profile_name = "EC2InstanceProfile"  # Perfil de la instancia
  instance_type       = "t3.micro"  # Tipo de instancia
}

resource "aws_image_builder_image_pipeline" "example_pipeline" {
  name        = "example-pipeline"
  description = "Pipeline for building AMI with custom workflow"
  
  image_recipe_arn                    = aws_image_builder_image_recipe.example_recipe.arn
  infrastructure_configuration_arn     = aws_image_builder_infrastructure_configuration.example_infrastructure.arn
  
  status = "ENABLED"

  # Usando el workflow predefinido de AWS
  build {
    workflow {
      arn = "arn:aws:imagebuilder:eu-south-2:aws:workflow/build/build-image/1.0.2"
    }
    schedule {
      frequency = "Daily"  # Ejemplo: puedes hacer que se ejecute diariamente
      start_time = "00:00"
    }
  }
}

resource "aws_image_builder_image" "example_image" {
  image_recipe_arn                = aws_image_builder_image_recipe.example_recipe.arn
  infrastructure_configuration_arn = aws_image_builder_infrastructure_configuration.example_infrastructure.arn
  pipeline_arn                    = aws_image_builder_image_pipeline.example_pipeline.arn
}
