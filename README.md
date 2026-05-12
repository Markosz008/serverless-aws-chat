# 🟢 Serverless AWS Real-Time Chat & Communication Hub

A fully serverless, real-time communication application built on AWS. This project goes far beyond a simple chat: it features peer-to-peer WebRTC video calling, an integrated Generative AI Chatbot (Amazon Bedrock), rich media handling (voice notes, drawings), and Progressive Web App (PWA) capabilities. It demonstrates advanced event-driven architecture, Infrastructure as Code (IaC) with Terraform, and frontend-backend separation.

## 🚀 Architecture Overview

This project does not use traditional servers or constantly running containers. It scales automatically to millions of users and scales down to zero when not in use, meaning the infrastructure cost is practically $0 when idle.

* **Frontend:** A lightweight HTML/JS/CSS Progressive Web App hosted on an **AWS S3 Bucket**.
* **CDN & Security:** Distributed globally via **Amazon CloudFront** providing a secure `HTTPS` endpoint, with automated Terraform cache invalidation.
* **Connection Management:** **AWS API Gateway (WebSocket API)** handles the persistent connections natively.
* **Backend Logic:** Event-driven **AWS Lambda** functions (Python) that only run for milliseconds to process messages, signals, and API calls.
* **State Management:** **Amazon DynamoDB** stores active `connectionId`s, chat history, and room metadata.
* **Media Storage:** An **Amazon S3 Bucket** securely stores images, voice notes, and canvas drawings bypassing API limits via Pre-signed URLs.
* **Generative AI:** **Amazon Bedrock** (Claude 3.5 / 4.5 models) powers the interactive AI "Dungeon Master" bot directly within the chat.

## 🛠️ Tech Stack

* **Infrastructure as Code:** HashiCorp Terraform
* **Cloud Provider:** Amazon Web Services (AWS)
* **Backend:** Python 3.9 (Boto3)
* **Frontend:** Vanilla HTML5, CSS3, JavaScript (WebSocket API, WebRTC API, Canvas API)
* **Integrations:** Amazon Bedrock (Anthropic Claude), DiceBear API (Avatars)

## ✨ Key Features

### 💬 Advanced Chat Capabilities
* **Real-Time Communication:** Sub-second latency via WebSockets.
* **Private Rooms:** Users can create or join specific channels with optional password protection.
* **Message Replies & Quoting:** Contextual replies with visual previews.
* **Read Receipts & Status:** WhatsApp-style message statuses (🕒 Pending, ✓ Sent, ✓✓ Read).
* **Rich Link Previews (Unfurling):** Backend automatically fetches OpenGraph data to generate rich UI cards for YouTube and external links.
* **Interactive Emoji Reactions:** Long-press (mobile) or hover (desktop) to toggle reactions (❤️, 👍, 😂, 😮, 🔥).

### 📞 WebRTC Video & Audio Calling
* **Peer-to-Peer Encrypted Calls:** Built-in 1-on-1 video calling using WebRTC.
* **Custom Signaling:** The WebSocket API acts as the signaling server to exchange SDP offers and ICE candidates.
* **Media Controls:** Users can seamlessly toggle their camera off to transition into an audio-only call.

### 🤖 AI "Dungeon Master" (GenAI Integration)
* **Interactive Storytelling:** By typing `/kaland [action]`, users can interact with an AI-powered Game Master (Claude via Amazon Bedrock) that generates dynamic, fantasy-style responses and challenges directly into the chat stream.

### 🎨 Rich Media & Collaboration
* **Live Drawing Board:** A built-in HTML5 Canvas where users can sketch and instantly send their artwork as a PNG image to the chat via S3.
* **Voice Notes:** In-browser audio recording that uploads `.webm`/`.m4a` files on the fly.
* **Image Uploads & Lightbox:** Secure, direct-to-S3 image uploads using dynamically generated Pre-signed URLs, complete with a full-screen zoomable lightbox.

### 📱 Modern UI/UX
* **Progressive Web App (PWA):** Installable on iOS/Android and Desktop for a native app-like experience.
* **Dynamic Avatars:** Auto-generated, customizable user avatars via the DiceBear API (with a "roll" button to change seeds).
* **Dark/Light Mode:** Toggleable UI themes for comfortable reading.
* **Responsive Design:** WhatsApp-style message bubbles that perfectly adapt to all screen sizes.

## ⚙️ How It Works (The Flow)

1. **Connection:** User opens the CloudFront URL. The browser initiates a WebSocket connection to the API Gateway (`$connect` route), which triggers a Lambda to store the `connectionId` in DynamoDB.
2. **Messaging & History:** When a user joins a room, Lambda fetches the recent message history from DynamoDB. New messages are broadcasted to all active connections in that specific room.
3. **WebRTC Signaling:** When a user initiates a call, the frontend generates a WebRTC Offer. The WebSocket backend routes this payload strictly to the target user, establishing a direct P2P connection.
4. **Media Uploading (Voice/Images/Drawings):** The client requests an upload URL. Lambda generates a secure, time-limited S3 Pre-signed URL. The client uploads the blob *directly* to S3, then broadcasts the final public URL to the chat.
5. **AI Invocation:** Messages starting with `/kaland` trigger the Lambda to invoke the Amazon Bedrock `converse` API. The backend waits for the AI's response and broadcasts it as a system user.

## 🚀 Deployment Instructions

To deploy this infrastructure to your own AWS account using Terraform:

1. Clone the repository.
2. Navigate to the `terraform` directory: `cd terraform`
3. Initialize Terraform: `terraform init -upgrade`
4. Deploy the infrastructure: `terraform apply --auto-approve`
5. Terraform will automatically:
   * Provision all AWS resources (DynamoDB, Lambda, API Gateway, S3, CloudFront).
   * Inject the dynamically generated WebSocket URL into your `index.html.tpl` file.
   * Invalidate the CloudFront cache to ensure immediate updates.
6. Make sure to enable the appropriate **Anthropic Claude** model in the AWS Bedrock Console (Model Access).
7. Open the provided CloudFront URL in your browser and start chatting!

To destroy the infrastructure and stop incurring charges:
`terraform destroy --auto-approve`
