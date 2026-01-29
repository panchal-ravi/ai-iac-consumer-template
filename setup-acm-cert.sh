#!/bin/bash
# Setup ACM Certificate for ALB HTTPS Listener
# This script generates a self-signed certificate and imports it to ACM

set -e

echo "=== Generating self-signed certificate for ALB ==="

# Generate private key and certificate
openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
  -keyout alb-private-key.pem \
  -out alb-certificate.pem \
  -subj "/C=SG/ST=Singapore/L=Singapore/O=Development/CN=*.elb.amazonaws.com" \
  2>/dev/null

echo "✓ Certificate and private key generated"

# Import to ACM
echo "=== Importing certificate to ACM ==="
CERT_ARN=$(aws acm import-certificate \
  --certificate fileb://alb-certificate.pem \
  --private-key fileb://alb-private-key.pem \
  --region ap-southeast-1 \
  --query 'CertificateArn' \
  --output text)

echo "✓ Certificate imported to ACM"
echo ""
echo "Certificate ARN: $CERT_ARN"
echo ""
echo "Update sandbox.auto.tfvars with:"
echo "acm_certificate_arn = \"$CERT_ARN\""
echo ""

# Clean up files
rm -f alb-private-key.pem alb-certificate.pem
echo "✓ Cleaned up certificate files"
