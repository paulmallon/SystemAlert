# SystemAlert
AWS Lambda function written for Powershell 6 

## Description
- Grabs opening hours from the public systembolaget.se api (/api/assortment/stores/xml)
- Publish message to SNS topic if irregular opening hours detected. 

## Demo
API Gateway used to invoke the Lambda functions. 

https://hngh0n05va.execute-api.eu-central-1.amazonaws.com/Dev



## Prerequisites
* AWS CLI
* AWS .NET Core CLI
* AWSLambdaPSCore deplyment tools 

## Deployment 
https://docs.aws.amazon.com/lambda/latest/dg/lambda-powershell-how-to-create-deployment-package.html

## VS Code settings
```
{
    "terminal.integrated.shell.windows": "C:\\Program Files\\PowerShell\\6\\pwsh.exe",
    "powershell.powerShellExePath": "C:\\Program Files\\PowerShell\\6\\pwsh.exe"
}
```
