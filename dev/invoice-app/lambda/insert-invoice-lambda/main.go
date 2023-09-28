package main

import (
	"context"
	"encoding/json"
	"fmt"
	"net/http"
	"os"

	"github.com/aws/aws-lambda-go/events"
	"github.com/aws/aws-lambda-go/lambda"
	"github.com/aws/aws-sdk-go/aws"
	"github.com/aws/aws-sdk-go/aws/session"
	"github.com/aws/aws-sdk-go/service/dynamodb"
	"github.com/aws/aws-sdk-go/service/dynamodb/dynamodbattribute"
)

type Invoice struct {
	InvoiceID   string   `json:"InvoiceID"`
	CustomerID  string   `json:"CustomerID"`
	InvoiceDate string   `json:"InvoiceDate"`
	ProductList []string `json:"ProductList"`
	TotalAmount int      `json:"TotalAmount"`
}


func HandleRequest(ctx context.Context, request events.APIGatewayProxyRequest) (events.APIGatewayProxyResponse, error) {
	if request.HTTPMethod != "POST" {
		return events.APIGatewayProxyResponse{
			StatusCode: http.StatusMethodNotAllowed,
			Body:       "Invalid request method",
		}, nil
	}

	var invoice Invoice
	err := json.Unmarshal([]byte(request.Body), &invoice)
	if err != nil {
		return events.APIGatewayProxyResponse{
			StatusCode: http.StatusInternalServerError,
			Body:       "Error decoding request body",
		}, nil
	}

	err = InsertIntoDynamoDB(&invoice)
	if err != nil {
		return events.APIGatewayProxyResponse{
			StatusCode: http.StatusInternalServerError,
			Body:       fmt.Sprintf("Failed to insert into DynamoDB: %v", err),
		}, nil
	}

	return events.APIGatewayProxyResponse{
		StatusCode: http.StatusOK,
		Body:       "Successfully inserted into DynamoDB",
	}, nil
}

func InsertIntoDynamoDB(invoice *Invoice) error {
	sess, err := session.NewSession(&aws.Config{
		Region: aws.String(os.Getenv("AWS_REGION")),
	})
	if err != nil {
		return err
	}

	svc := dynamodb.New(sess)

	item, err := dynamodbattribute.MarshalMap(invoice)
	if err != nil {
		return err
	}

	input := &dynamodb.PutItemInput{
		Item:      item,
		TableName: aws.String(os.Getenv("DYNAMODB_TABLE_NAME")),
	}

	_, err = svc.PutItem(input)
	return err
}

func main() {
	lambda.Start(HandleRequest)
}
