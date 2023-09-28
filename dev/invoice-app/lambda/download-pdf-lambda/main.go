package main

import (
	"context"
	"errors"
	"fmt"
	"log"
	"os"
	"time"

	"github.com/aws/aws-lambda-go/events"
	"github.com/aws/aws-lambda-go/lambda"
	"github.com/aws/aws-sdk-go/aws"
	"github.com/aws/aws-sdk-go/aws/session"
	"github.com/aws/aws-sdk-go/service/dynamodb"
	"github.com/aws/aws-sdk-go/service/s3"
)

var (
	dynamoSvc  = dynamodb.New(session.Must(session.NewSession()))
	s3Svc      = s3.New(session.Must(session.NewSession()))
	tableName  = os.Getenv("DYNAMODB_TABLE_NAME")
	bucketName = os.Getenv("S3_BUCKET_NAME")
)

func generatePresignedURL(s3Key string) (string, error) {
	req, _ := s3Svc.GetObjectRequest(&s3.GetObjectInput{
		Bucket: aws.String(bucketName),
		Key:    aws.String(s3Key),
	})
	urlStr, err := req.Presign(15 * time.Minute)
	if err != nil {
		return "", fmt.Errorf("failed to sign request: %v", err)
	}
	return urlStr, nil
}

func getS3KeyFromDynamo(InvoiceID string) (string, error) {
	result, err := dynamoSvc.GetItem(&dynamodb.GetItemInput{
		TableName: aws.String(tableName),
		Key: map[string]*dynamodb.AttributeValue{
			"InvoiceID": {
				S: aws.String(InvoiceID),
			},
		},
	})
	if err != nil {
		return "", fmt.Errorf("error querying DynamoDB: %v", err)
	}
	if result.Item == nil || result.Item["S3Key"] == nil || result.Item["S3Key"].S == nil {
		return "", errors.New("InvoiceID not found")
	}
	return *result.Item["S3Key"].S, nil
}

func handler(ctx context.Context, request events.APIGatewayProxyRequest) (events.APIGatewayProxyResponse, error) {
	InvoiceID := request.QueryStringParameters["InvoiceID"]
	if InvoiceID == "" {
		return events.APIGatewayProxyResponse{StatusCode: 400, Body: "InvoiceID is missing"}, nil
	}

	s3Key, err := getS3KeyFromDynamo(InvoiceID)
	if err != nil {
		log.Printf("Error fetching S3Key: %v", err)
		if errors.Is(err, errors.New("InvoiceID not found")) {
			return events.APIGatewayProxyResponse{StatusCode: 404, Body: err.Error()}, nil
		}
		return events.APIGatewayProxyResponse{StatusCode: 500, Body: "Error querying DynamoDB"}, nil
	}

	presignedURL, err := generatePresignedURL(s3Key)
	if err != nil {
		log.Printf("Error generating presigned URL: %v", err)
		return events.APIGatewayProxyResponse{StatusCode: 500, Body: "Error generating presigned URL"}, nil
	}

	return events.APIGatewayProxyResponse{StatusCode: 200, Body: presignedURL}, nil
}

func main() {
	lambda.Start(handler)
}
