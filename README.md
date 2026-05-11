# 🟢 Serverless AWS Real-Time Chat Application

A fully serverless, real-time chat application built on AWS using WebSockets. This project demonstrates event-driven architecture, Infrastructure as Code (IaC) with Terraform, frontend-backend separation, and rich media handling.

## 🚀 Architecture Overview

This project does not use traditional servers or constantly running containers. It scales automatically to millions of users and scales down to zero when not in use, meaning the infrastructure cost is practically $0 when idle.

* **Frontend:** A lightweight HTML/JS/CSS client hosted on an **AWS S3 Bucket**.
* **CDN & Security:** Distributed globally via **Amazon CloudFront** providing a secure `HTTPS` endpoint.
* **Connection Management:** **AWS API Gateway (WebSocket API)** handles the persistent connections so the backend doesn't have to.
* **Backend Logic:** An event-driven **AWS Lambda** function (Python) that only runs for milliseconds when a message is sent, an image is uploaded, or a reaction is added.
* **State Management:** **Amazon DynamoDB** stores the active `connectionId`s and usernames of currently online users.
* **Media Storage:** An additional **Amazon S3 Bucket** securely stores user-uploaded images bypassing API limits via Pre-signed URLs.

## 🛠️ Tech Stack

* **Infrastructure as Code:** Terraform
* **Cloud Provider:** Amazon Web Services (AWS)
* **Backend:** Python 3.9 (Boto3)
* **Frontend:** Vanilla HTML5, CSS3, JavaScript (WebSocket API, Emoji-Picker-Element)

## ✨ Features

* **Real-Time Communication:** Sub-second latency using WebSockets.
* **Zero-Idle Cost:** 100% Serverless architecture.
* **Media Uploads:** Secure, direct-to-S3 image uploads using dynamically generated Pre-signed URLs.
* **Interactive Emoji Reactions:** Users can react to messages (❤️, 👍, 😂, 😮, 🔥). Features a hover-menu for desktop and a native-feeling long-press menu for mobile devices. Supports toggle (add/remove) logic.
* **Lightbox Viewer:** Click to expand images in a distraction-free, full-screen overlay without breaking the chat flow.
* **Dark/Light Mode:** Toggleable UI themes for comfortable day or night reading.
* **Live User List:** Real-time presence detection showing who is currently online.
* **Responsive UI/UX:** Modern, WhatsApp-style message bubbles that perfectly adapt to desktop and mobile screens.

## ⚙️ How It Works (The Flow)

1. User opens the CloudFront URL. The browser requests the frontend from S3.
2. The browser initiates a WebSocket connection to the API Gateway (`$connect` route).
3. API Gateway triggers the Lambda function, which saves the unique `connectionId` and username into DynamoDB.
4. **Messaging:** When a user sends a message (`sendMessage` route), Lambda fetches all active IDs from DynamoDB and broadcasts the message back to all connected clients.
5. **Image Uploading:** The client requests an upload URL. Lambda generates a secure, time-limited S3 Pre-signed URL. The client uploads the image *directly* to S3, then broadcasts the final image URL to the chat.
6. **Reactions:** Reacting to a message sends a `sendReaction` event to Lambda, which instantly broadcasts the UI update to all clients.
7. **Disconnect:** Upon leaving the page, the client performs a clean disconnect, and Lambda removes the ID from DynamoDB, updating the online user list.

## 🚀 Deployment Instructions

To deploy this infrastructure to your own AWS account using Terraform:

1. Clone the repository.
2. Navigate to the `terraform` directory: `cd terraform`
3. Initialize Terraform: `terraform init`
4. Deploy the infrastructure: `terraform apply --auto-approve`
5. Terraform automatically injects the dynamically generated WebSocket URL into your `index.html.tpl` file and uploads it to the S3 bucket.
6. Open the provided CloudFront URL in your browser and start chatting!

To destroy the infrastructure and stop incurring charges (though it fits well within the AWS Free Tier):
`terraform destroy --auto-approve`