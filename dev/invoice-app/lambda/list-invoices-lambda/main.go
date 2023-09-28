package main

import (
	"encoding/json"
	"fmt"
	"os"

	"github.com/aws/aws-lambda-go/events"
	"github.com/aws/aws-lambda-go/lambda"
	"github.com/aws/aws-sdk-go/aws"
	"github.com/aws/aws-sdk-go/aws/session"
	"github.com/aws/aws-sdk-go/service/dynamodb"
	"github.com/aws/aws-sdk-go/service/dynamodb/dynamodbattribute"
)

type Invoice struct {
	InvoiceID    string   `json:"InvoiceID"`
	CustomerID   string   `json:"CustomerID"`
	TotalAmount  float64  `json:"TotalAmount"`
	InvoiceDate  string   `json:"InvoiceDate"`
	ProductList  []string `json:"ProductList"`
}

func ListInvoices(request events.APIGatewayProxyRequest) (events.APIGatewayProxyResponse, error) {
	customerID := request.QueryStringParameters["customerId"]
	if customerID == "" {
		return events.APIGatewayProxyResponse{
			StatusCode: 400,
			Body:       "customerId parameter is required",
		}, nil
	}

	// Reading DynamoDB table name from environment variable
	tableName, exists := os.LookupEnv("dynamodb_table_name")
	if !exists {
		return events.APIGatewayProxyResponse{}, fmt.Errorf("dynamodb_table_name environment variable is not set")
	}

	region, exists := os.LookupEnv("AWS_REGION")
	if !exists {
		return events.APIGatewayProxyResponse{}, fmt.Errorf("AWS_REGION environment variable is not set")
	}

	sess, err := session.NewSession(&aws.Config{
		Region: aws.String(region),
	})

	if err != nil {
		return events.APIGatewayProxyResponse{}, err
	}
	
	gsiName, exists := os.LookupEnv("global_secondary_index_name")
	if !exists {
		return events.APIGatewayProxyResponse{}, fmt.Errorf("global_secondary_index_name environment variable is not set")
	}

	gsiHashKey, exists := os.LookupEnv("global_secondary_index_hash_key")
	if !exists {
		return events.APIGatewayProxyResponse{}, fmt.Errorf("global_secondary_index_hash_key environment variable is not set")
	}
	svc := dynamodb.New(sess)
	queryInput := &dynamodb.QueryInput{
		TableName: aws.String(tableName),
		IndexName: aws.String(gsiName),
		KeyConditions: map[string]*dynamodb.Condition{
		  gsiHashKey: {
			ComparisonOperator: aws.String("EQ"),
			AttributeValueList: []*dynamodb.AttributeValue{
			  {
				S: aws.String(customerID),
			  },
			},
		  },
		},
	  }

	queryOutput, err := svc.Query(queryInput)
	if err != nil {
		return events.APIGatewayProxyResponse{}, err
	}

	var invoices []Invoice
	err = dynamodbattribute.UnmarshalListOfMaps(queryOutput.Items, &invoices)
	if err != nil {
		return events.APIGatewayProxyResponse{}, err
	}

	jsonInvoices, err := json.Marshal(invoices)
	if err != nil {
		return events.APIGatewayProxyResponse{}, err
	}

	return events.APIGatewayProxyResponse{
		StatusCode: 200,
		Body:       string(jsonInvoices),
	}, nil
}

func main() {
	lambda.Start(ListInvoices)
}
