# --- layer.tf ---

# 1. Lokális változó a mappa definiálásához
locals {
  layer_path = "${path.module}/layer_src/python"
}

# 2. Egy Null Resource, ami letölti a pip csomagokat egy mappába, ha a requirements.txt változik
resource "null_resource" "pip_install" {
  triggers = {
    # Kicsit módosítjuk a hasht, hogy újra lefuttassa
    dependencies_hash = md5("pywebpush==2.3.0 typing-extensions==4.11.0 linux-build-v2") 
  }

  provisioner "local-exec" {
    command = <<EOF
      rm -rf ${local.layer_path}
      mkdir -p ${local.layer_path}
      
      # 1. Lépés: Letöltünk mindent normálisan (feltelepül a pure-python http-ece és a Mac-es cryptography)
      pip3 install pywebpush==2.3.0 typing-extensions==4.11.0 -t ${local.layer_path}
      
      # 2. Lépés: A problémás cryptography modult erőszakosan felülírjuk a Lambda-kompatibilis Linux verzióval
      pip3 install cryptography -t ${local.layer_path} --upgrade --platform manylinux2014_x86_64 --implementation cp --python-version 3.12 --only-binary=:all:
    EOF
  }
}

# 3. Zippeljük össze a letöltött csomagokat
data "archive_file" "layer_zip" {
  type        = "zip"
  source_dir  = "${path.module}/layer_src" # A teljes mappát (benne a /python-nal) zippeljük
  output_path = "${path.module}/webpush_layer.zip"
  depends_on  = [null_resource.pip_install]
}

# 4. Maga az AWS Lambda Layer erőforrás
resource "aws_lambda_layer_version" "webpush_layer" {
  layer_name          = "pywebpush_layer"
  description         = "PyWebPush library for VAPID notifications"
  filename            = data.archive_file.layer_zip.output_path
  source_code_hash    = data.archive_file.layer_zip.output_base64sha256
  compatible_runtimes = ["python3.9", "python3.10", "python3.11", "python3.12"] # Állítsd be a Lambdád verzióját
}