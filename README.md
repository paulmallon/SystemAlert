# SystemAlert
AWS Lambda function written for Powershell 6 

## Description
- Grabs opening hours from the public systembolaget.se api (/api/assortment/stores/xml)
- Publish message to SNS topic if irregular opening hours detected. 


## Prerequisites
* Powershell
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
