package main

import (
	"fmt"
	"os"

	"github.com/aws/aws-lambda-go/lambda"
	"github.com/aws/aws-sdk-go/aws"
	"github.com/aws/aws-sdk-go/aws/session"
	"github.com/aws/aws-sdk-go/service/dynamodb"
	"github.com/aws/aws-sdk-go/service/dynamodb/dynamodbattribute"
)

type Invoice struct {
	InvoiceID    string  `json:"InvoiceID"`
	CustomerID   string  `json:"CustomerID"`
	TotalAmount  float64 `json:"TotalAmount"`
	InvoiceDate  string  `json:"InvoiceDate"`
	ProductList  []string `json:"ProductList"`
}

func CreateInvoices() (string, error) {
	// Reading DynamoDB table name from environment variable
	tableName, exists := os.LookupEnv("dynamodb_table_name")
	if !exists {
		return "", fmt.Errorf("dynamodb_table_name environment variable is not set")
	}

	region, exists := os.LookupEnv("AWS_REGION")
	if !exists {
		return "", fmt.Errorf("AWS_REGION environment variable is not set")
	}
	
	sess, err := session.NewSession(&aws.Config{
        Region: aws.String(region), 
    })

    if err != nil {
        return "", err
    }

	svc := dynamodb.New(sess)

	for i := 1; i <= 100; i++ {
		invoice := Invoice{
			InvoiceID:   fmt.Sprintf("INV%d", i),
			CustomerID:  fmt.Sprintf("CUST%d", i),
			TotalAmount: 1.0,
			InvoiceDate: "2023-09-26",
			ProductList: []string{"Item1", "Item2"},
		}

		av, err := dynamodbattribute.MarshalMap(invoice)
		if err != nil {
			return "", err
		}

		input := &dynamodb.PutItemInput{
			Item:      av,
			TableName: aws.String(tableName),
		}

		_, err = svc.PutItem(input)
		if err != nil {
			return "", err
		}
	}

	return "100 invoices created successfully.", nil
}

func main() {
	lambda.Start(CreateInvoices)
}
