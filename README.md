# 🟢 Serverless AWS Real-Time Chat Application

A fully serverless, real-time chat application built on AWS using WebSockets. This project demonstrates event-driven architecture, Infrastructure as Code (IaC) with Terraform, and frontend-backend separation.

## 🚀 Architecture Overview

This project does not use traditional servers or constantly running containers. It scales automatically to millions of users and scales down to zero when not in use, meaning the infrastructure cost is practically $0 when idle.

* **Frontend:** A lightweight HTML/JS/CSS client hosted on an **AWS S3 Bucket**.
* **CDN & Security:** Distributed globally via **Amazon CloudFront** providing a secure `HTTPS` endpoint.
* **Connection Management:** **AWS API Gateway (WebSocket API)** handles the persistent connections so the backend doesn't have to.
* **Backend Logic:** An event-driven **AWS Lambda** function (Python) that only runs for milliseconds when a message is sent.
* **State Management:** **Amazon DynamoDB** stores the active `connectionId`s of currently online users.

## 🛠️ Tech Stack

* **Infrastructure as Code:** Terraform
* **Cloud Provider:** Amazon Web Services (AWS)
* **Backend:** Python 3.9 (Boto3)
* **Frontend:** Vanilla HTML5, CSS3, JavaScript (WebSocket API)

## ✨ Features

* **Real-Time Communication:** Sub-second latency using WebSockets.
* **Zero-Idle Cost:** 100% Serverless architecture.
* **Custom Usernames:** Users can enter a nickname upon joining.
* **UI/UX:** Modern, WhatsApp-style message bubbles (green for others, orange for self).
* **Browser Notifications:** Uses HTML5 Notification API to alert users of new messages when the chat tab is inactive.

## ⚙️ How It Works (The Flow)

1. User opens the CloudFront URL. The browser requests the frontend from S3.
2. The browser initiates a WebSocket connection to the API Gateway (`$connect` route).
3. API Gateway triggers the Lambda function, which saves the unique `connectionId` into DynamoDB.
4. When a user sends a message (`sendMessage` route), Lambda fetches all active IDs from DynamoDB.
5. Lambda uses the API Gateway Management API to broadcast the message back to all connected clients.
6. Upon leaving (`$disconnect` route), Lambda removes the ID from DynamoDB.

## 🚀 Deployment Instructions

To deploy this infrastructure to your own AWS account using Terraform:

1. Clone the repository.
2. Navigate to the `terraform` directory: `cd terraform`
3. Initialize Terraform: `terraform init`
4. Deploy the infrastructure: `terraform apply --auto-approve`
5. Note the output URLs. Paste the WebSocket URL (`wss://...`) into the `index.html` file.
6. Run `terraform apply` again to push the updated HTML to the S3 bucket.
7. Open the provided CloudFront URL in your browser!

To destroy the infrastructure and stop incurring charges (though it fits well within the AWS Free Tier):
`terraform destroy --auto-approve`