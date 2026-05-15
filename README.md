# 🟢 Serverless AWS Real-Time Chat & Communication Hub

A fully serverless, real-time communication application built on AWS. This project goes far beyond a simple chat: it features peer-to-peer WebRTC video calling, End-to-End Encryption (E2EE), an integrated Generative AI Game Master (Amazon Bedrock), rich media handling, and Progressive Web App (PWA) capabilities with native Web Push notifications. It demonstrates advanced event-driven architecture, Infrastructure as Code (IaC) with Terraform, and frontend-backend separation.

## 🚀 Architecture Overview

This project does not use traditional servers or constantly running containers. It scales automatically to millions of users and scales down to zero when not in use, meaning the infrastructure cost is practically $0 when idle.

* **Frontend:** A lightweight HTML/JS/CSS Progressive Web App hosted on an **AWS S3 Bucket**.
* **CDN & Security:** Distributed globally via **Amazon CloudFront** providing a secure `HTTPS` endpoint, with automated Terraform cache invalidation.
* **Connection Management:** **AWS API Gateway (WebSocket API)** handles the persistent connections natively.
* **Backend Logic:** Event-driven, **memory-optimized (512MB) AWS Lambda** functions (Python) that run only for milliseconds. The memory footprint is deliberately tuned to balance cost-efficiency with rapid execution, drastically reducing cold-start times when initializing heavy libraries like `boto3`.
* **State Management:** **Amazon DynamoDB** (Pay-Per-Request) stores active `connectionId`s, chat history, push subscriptions, and room metadata.
* **Media Storage:** Dedicated **Amazon S3 Buckets** securely store images, voice notes, avatars, and canvas drawings bypassing API limits via time-limited Pre-signed URLs.
* **Generative AI:** **Amazon Bedrock** powers the interactive AI "Dungeon Master" bot directly within the chat, supported by AWS Transcribe and Polly.

## 🛠️ Tech Stack

* **Infrastructure as Code:** HashiCorp Terraform
* **Cloud Provider:** Amazon Web Services (AWS)
  * Compute: Lambda, API Gateway (WebSocket), CloudFront
  * Storage: DynamoDB, S3
  * AI & ML: Amazon Bedrock (Claude / Stable Image Core), Amazon Transcribe, Amazon Polly
* **Backend:** Python 3.12 (Boto3, PyWebPush)
* **Frontend:** Vanilla HTML5, CSS3, JavaScript (WebSocket API, WebRTC API, Canvas API, Service Workers, WebCrypto API)
* **Integrations:** DiceBear API (Avatars)

## ✨ Key Features

### 🔒 Security & Privacy
* **End-to-End Encryption (E2EE):** A dedicated "Secret Mode" utilizing the native WebCrypto API. Passwords are used to derive cryptographic keys via `PBKDF2`, and messages are encrypted locally using `AES-GCM` before ever hitting the network. The AWS backend only routes the encrypted payloads (Base64), ensuring a zero-knowledge architecture.

### 💬 Advanced Chat Capabilities
* **Real-Time Communication:** Sub-second latency via WebSockets.
* **Private Rooms & Invites:** Users can create password-protected channels and actively invite or "ping" other online users to join specific groups seamlessly.
* **Message Editing & Revocation:** Users can edit sent messages or permanently "unsend" (revoke) them for all participants. The backend handles logical deletion (`DELETED_MSG`) to maintain database consistency.
* **Resilient Connection Handling:** "Ghost socket" protection and aggressive reconnection logic. The app gracefully handles mobile lifecycle events (e.g., waking up from background), automatically flushing unread message queues and syncing read receipts (`markRead`).
* **Rich Link Previews (Unfurling):** Backend automatically fetches OpenGraph data to generate rich UI cards for YouTube and external links.

### 🔔 Native Push Notifications
* **Web Push API:** Implemented VAPID-based push notifications utilizing Service Workers and a dedicated DynamoDB subscription table. Users receive offline notifications for new messages, making the PWA feel exactly like a native mobile app.

### 🤖 AI "Dungeon Master" (GenAI, Audio & FinOps)
* **Interactive Storytelling:** By typing `/kaland [action]`, users can interact with an AI-powered Game Master (Claude via Amazon Bedrock) that generates dynamic, fantasy-style responses directly in the chat stream.
* **Cost-Optimized Voice-to-Text:** To strictly operate within the AWS Free Tier, automatic voice transcription is feature-flagged. Users can send voice commands to the AI, which are asynchronously converted to text using **Amazon Transcribe**.
* **Text-to-Speech (TTS):** Utilizing **Amazon Polly**, the Dungeon Master can vocalize its responses, creating a fully immersive, voice-driven interaction.

### 🎨 AI Image Generation & Multi-Model Chaining
* **Text-to-Image via Amazon Bedrock:** Users can generate custom images directly in the chat using the `/kep [prompt]` command.
* **Intelligent Translation Chain:** The backend employs a multi-model approach. A lightweight LLM (Anthropic Claude 3 Haiku) automatically translates Hungarian prompts into English, which are then fed into the `stability.stable-image-core-v1:1` model for high-quality image generation. The resulting images are securely uploaded to S3 and broadcasted.

### 📞 WebRTC Video & Audio Calling
* **Peer-to-Peer Encrypted Calls:** Built-in 1-on-1 video calling using WebRTC.
* **Custom Signaling:** The WebSocket API acts as the signaling server to exchange SDP offers and ICE candidates.
* **Media Controls:** Users can seamlessly toggle their camera off to transition into an audio-only call.

### 📱 Modern UI/UX & Collaboration
* **Theming Engine:** A robust CSS-variable-based theming system supporting Dark/Light modes, and completely custom user-selectable themes including **Retro (Matrix-style Terminal)**, **Cyberpunk**, and **Pastel**.
* **Custom User Avatars:** Users can personalize their profiles using dynamic emojis or by uploading custom profile pictures to a dedicated S3 Avatar Bucket.
* **Seamless Media Viewing:** Integrated custom Lightbox for viewing high-resolution uploaded images and AI-generated artwork directly within the PWA, without losing chat context.
* **Live Drawing Board:** A built-in HTML5 Canvas where users can sketch and instantly send their artwork as a PNG image to the chat via S3.

## ⚙️ How It Works (The Flow)

1. **Connection:** User opens the CloudFront URL. The browser initiates a WebSocket connection to the API Gateway (`$connect` route), which triggers a Lambda to store the `connectionId` in DynamoDB.
2. **Messaging & History:** When a user joins a room, Lambda fetches the recent message history from DynamoDB. New messages are broadcasted to all active connections in that specific room.
3. **WebRTC Signaling:** When a user initiates a call, the frontend generates a WebRTC Offer. The WebSocket backend routes this payload strictly to the target user, establishing a direct P2P connection.
4. **Media Uploading (Voice/Images/Drawings):** The client requests an upload URL. Lambda generates a secure, time-limited S3 Pre-signed URL. The client uploads the blob *directly* to S3, then broadcasts the final public URL to the chat.
5. **AI & Voice Invocation:** Messages starting with `/kaland` trigger a Lambda function. If the input is a voice note, Lambda initiates an **Amazon Transcribe** job. The resulting text is sent to the **Amazon Bedrock** `converse` API. The AI's response is optionally converted back to audio via **Amazon Polly**, and broadcasted to the room as the Game Master.

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
6. Make sure to enable the appropriate **Anthropic Claude** and **Stable Image Core** models in the AWS Bedrock Console (Model Access).
7. Open the provided CloudFront URL in your browser and start chatting!

To destroy the infrastructure and stop incurring charges:
`terraform destroy --auto-approve`
