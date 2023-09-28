package main

import (
	"bytes"
	"context"
	"fmt"
	"log"
	"os"
	"strconv"

	"github.com/aws/aws-lambda-go/events"
	"github.com/aws/aws-lambda-go/lambda"
	"github.com/aws/aws-sdk-go/aws"
	"github.com/aws/aws-sdk-go/aws/session"
	"github.com/aws/aws-sdk-go/service/dynamodb"
	"github.com/aws/aws-sdk-go/service/dynamodb/dynamodbattribute"
	"github.com/aws/aws-sdk-go/service/s3"
	"github.com/jung-kurt/gofpdf"
)

const (
	AWSRegionEnv          = "AWS_REGION"
	InvoiceDynamoDBTableEnv = "INVOICE_DYNAMODB_TABLE"
	PDFDynamoDBTableEnv     = "PDF_DYNAMODB_TABLE"
	S3BucketEnv           = "S3_BUCKET"
)

type Invoice struct {
	InvoiceID   string   `json:"InvoiceID"`
	CustomerID  string   `json:"CustomerID"`
	InvoiceDate string   `json:"InvoiceDate"`
	ProductList []string `json:"ProductList"`
	TotalAmount int      `json:"TotalAmount"`
}

type ProcessedInvoice struct {
	InvoiceID string `json:"InvoiceID" dynamodbav:"InvoiceID"`
	S3Key     string `json:"S3Key" dynamodbav:"s3key"`
}

func handleRequest(ctx context.Context, dynamoEvent events.DynamoDBEvent) {
	for _, record := range dynamoEvent.Records {
		if record.EventName == "INSERT" {
			if err := handleNewInvoice(record.Change.NewImage); err != nil {
				log.Printf("Failed processing new invoice: %v", err)
			}
		}
	}
}

func handleNewInvoice(item map[string]events.DynamoDBAttributeValue) error {
	totalAmount, err := strconv.Atoi(item["TotalAmount"].Number())
	if err != nil {
		return fmt.Errorf("error converting TotalAmount to int: %v", err)
	}

	invoice := Invoice{
		InvoiceID:   item["InvoiceID"].String(),
		CustomerID:  item["CustomerID"].String(),
		InvoiceDate: item["InvoiceDate"].String(),
		ProductList: []string{},
		TotalAmount: totalAmount,
	}

	for _, product := range item["ProductList"].List() {
		invoice.ProductList = append(invoice.ProductList, product.String())
	}

	pdfBuffer, err := generatePDF(invoice)
    if err != nil {
        return err
    }
    log.Printf("Successfully generated PDF for Invoice ID: %s", invoice.InvoiceID) 

    s3Key := fmt.Sprintf("%s.pdf", invoice.InvoiceID)
    if err := uploadToS3(s3Key, pdfBuffer); err != nil {
        return err
    }
    log.Printf("Successfully uploaded PDF to S3 with key: %s", s3Key) 

    if err := updateProcessedInvoiceTable(invoice.InvoiceID, s3Key); err != nil {
        return err
    }
    log.Printf("Successfully updated DynamoDB with Invoice ID: %s and S3 key: %s", invoice.InvoiceID, s3Key) 

    return nil
}

func generatePDF(invoice Invoice) (*bytes.Buffer, error) {
	pdf := gofpdf.New("P", "mm", "A4", "")
	pdf.AddPage()
	pdf.SetFont("Arial", "B", 16)

	pdf.Cell(40, 10, "Invoice ID: "+invoice.InvoiceID)
	// ... Add more content as needed

	var buf bytes.Buffer
	if err := pdf.Output(&buf); err != nil {
		return nil, fmt.Errorf("failed to generate PDF: %v", err)
	}
	return &buf, nil
}

func uploadToS3(s3Key string, pdfBuffer *bytes.Buffer) error {
	sess := session.Must(session.NewSession(&aws.Config{
		Region: aws.String(os.Getenv("AWS_REGION")),
	}))

	uploader := s3.New(sess)
	_, err := uploader.PutObject(&s3.PutObjectInput{
		Bucket: aws.String(os.Getenv("S3_BUCKET")),
		Key:    aws.String(s3Key),
		Body:   bytes.NewReader(pdfBuffer.Bytes()),
	})
	if err != nil {
		return fmt.Errorf("error uploading to S3: %v", err)
	}
	return nil
}

func updateProcessedInvoiceTable(invoiceID, s3Key string) error {
	sess := session.Must(session.NewSession(&aws.Config{
		Region: aws.String(os.Getenv("AWS_REGION")),
	}))

	dynamoDBSvc := dynamodb.New(sess)
	processedInvoice := ProcessedInvoice{
		InvoiceID: invoiceID,
		S3Key:     s3Key,
	}

	item, err := dynamodbattribute.MarshalMap(processedInvoice)
	if err != nil {
		return fmt.Errorf("error marshalling: %v", err)
	}

	input := &dynamodb.PutItemInput{
		Item:      item,
		TableName: aws.String(os.Getenv("PDF_DYNAMODB_TABLE")),
	}

	_, err = dynamoDBSvc.PutItem(input)
	if err != nil {
		return fmt.Errorf("error updating DynamoDB: %v", err)
	}
	return nil
}

func checkRequiredEnvironmentVariables() {
	requiredEnvs := []string{AWSRegionEnv, InvoiceDynamoDBTableEnv, PDFDynamoDBTableEnv, S3BucketEnv}
	for _, env := range requiredEnvs {
		if os.Getenv(env) == "" {
			log.Fatalf("ERROR: Missing environment variable %s", env)
		}
	}
}

func main() {
	checkRequiredEnvironmentVariables()
	lambda.Start(handleRequest)
}
