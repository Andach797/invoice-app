# Invoice App

## Overview
This repository contains the codebase for the Invoice App, a serverless application built on AWS using Terraform and Go. The application consists of various AWS services like API Gateway, DynamoDB, Lambda, and S3.

## Table of Contents
- [Overview](#overview)
- [Prerequisites](#prerequisites)
- [Initialization](#initialization)
- [Components](#components)
- [Resources](#resources)
- [Scripts](#scripts)

## Prerequisites
- AWS CLI
- Terraform
- Terragrunt
- Go

## Initialization

### Clone the Repository
```bash
git clone https://github.com/Andach797/invoice-app.git
cd invoice-app
````
### Plan
```bash
terragrunt run-all plan
````

### Initialize Terragrunt
Navigate to the dev directory and run:

```bash
terragrunt run-all apply
````

### Destroy Infrastructure
```bash
terragrunt run-all destroy
````
##
![Invoice App Diagram](https://github.com/Andach797/invoice-app/blob/main/invoice-app.jpg)

## Components
## Terraform Modules
### S3 
Data Blocks used to retrieve information about the current AWS caller identity and region, which can be used later in the configuration.

Force destroy enabled, allowing the bucket to be forcefully destroyed even if it contains objects since this is only for development environment.

Server side encryption enabled by defualt to specify server-side encryption using AES256.

Versioning enabled by default. Versioning in AWS S3 is used to maintain multiple versions of objects within a bucket. It provides an important data protection mechanism by allowing you to preserve, retrieve, and restore every version of every object stored in the bucket. This is valuable for data backup, recovery, and maintaining a historical record of changes to objects over time, ensuring that accidental deletions or overwrites can be easily recovered without data loss.

### DynamoDB

This Terraform configuration creates an AWS DynamoDB table and sets up auto-scaling policies. 

The DynamoDB table is provisioned with read and write capacities specified by input variables. 

It supports optional global secondary indexing to get data from DynamoDB with sort key if needed.
Server-side encryption and point-in-time recovery are enabled for added security and data protection. 
Auto-scaling targets and policies are established for both read and write capacities, utilizing predefined metrics to adjust capacity based on demand. This configuration ensures DynamoDB resources are efficiently provisioned and automatically scaled to handle varying workloads.
### Lambda
Defines the Lambda function with its attributes like function name, IAM role, runtime, and environment variables. It also configures S3 for deployment since Lambda deployment requires to has deployment package locally or on S3.

Creates an IAM role for the Lambda function with a specified assume role policy.
Attaches inline IAM policies to the Lambda execution role for additional permissions. This allows least privilege permissions for accessing other resources.
Sets up an event source mapping for DynamoDB triggers if enabled to trigger Lambda Functions with items from dynamodb.
Defines an IAM policy for CloudWatch Logs to allow logging attaches the CloudWatch Logs policy to the Lambda execution role default.
Creates an alias for the Lambda function for version management.
### API Gateway
This Terraform code sets up an AWS API Gateway and integrates it with AWS Lambda functions. The API Gateway resource defines the API's name and description, while the API Gateway Method configures HTTP methods with no authorization. The API Gateway Integration links the API to Lambda, using "AWS_PROXY" integration.

The Lambda Permission resource allows API Gateway to invoke Lambda functions securely. The API Gateway Deployment automates API deployment, with a SHA256 hash trigger for redeployment. The API Gateway Stage sets up an environment for the API, including optional access logging. This allows, with map values, creation of multiple Lambda Function integrations.

Additionally, it creates an API key for authentication and a usage plan to control access and rate limits. The API key is associated with the usage plan. If logging is enabled, a CloudWatch log group is created to store API Gateway logs.

## Resources
### S3
#### Artifacts Bucket
As mentioned earlier, this S3 bucket is used to store necessary artifacts for Lambda functions. Every Lambda function deployed here is facilitated by the before_hooks of Terragrunt.
#### PDF Bucket
This bucket is responsible for storing PDF files after processing. It includes a simple line of InvoiceID on the PDF files.
### DynamoDB
#### Invoices Table
This is where invoice data is stored. DynamoDB was chosen due to its powerful integration with streaming, offering a simple solution. With read/write capacity adjustments, it can even handle thousands of requests. Streaming is used to trigger the generation of PDF files when an item is inserted. InvoiceID serves as the hash key since it is the most unique key to avoid hot partition issues. A global secondary index for CustomerID is used to query invoices with this attribute.
#### Processed Invoices Table
This DynamoDB table is used to store data after PDF files are created. It has InvoiceID as the hash key and S3Key attributes. It stores the PDF object name when a download is needed.
### Lambda
Lambda was chosen for its ease of event handling with other AWS resources and its good scaling capabilities as a serverless solution. The backend is developed in GO for both efficient memory usage and to avoid cold starts since it is binary. Lambda has both initialization and invocation latencies. Initialization time involves downloading the code for Lambda, while invocation time is when the code can start to respond to requests. Programming languages like Java are considerably slower due to the JVM, and on serverless systems, even though the snap start feature seems to improve this problem.

#### Insert Mock Data Lambda
This Lambda function is triggered with after_hooks to create 100 mock data entries in the invoices table for testing purposes. If the apply is done again and there are items in the DynamoDB table, it won't create this data because it checks if the items exist.
#### Insert Invoice Lambda
This Lambda function receives invoice data from the API gateway and stores them in DynamoDB.
List Invoices Lambda
This Lambda function lists invoices for the customers sent to the API Gateway endpoint of list-invoices.
#### Generate PDF Lambda
This Lambda function is triggered by DynamoDB. It creates PDF files, stores them in the S3 bucket, and updates the Processed Invoices Table.
#### Download PDF Lambda
This Lambda function retrieves data from the API gateway for an invoice and checks the Processed Invoices Table. If S3Key is found, it creates a pre-signed URL for the PDF file and returns it.
### API Gateway
#### Invoice App API Gateway
This controls endpoints and routes them to Lambda functions. It includes API Key, usage plan, and CloudWatch monitoring, among other features. It creates integrations with lambdas using map values that contain lambda name, method, and resource path.
### Scripts
To avoid code repetition, two scripts are used:
#### build-script.sh 
This is for building Golang services with before hooks if they aren't found locally and uploads them if the checksum fails due to changes in the code zip file.
#### delete-all-files-and-version.sh
This script is added as a before hook to delete all remaining object versions since destroying the S3 bucket was failing because of them.
