# **Quizzi Documentation**

## **1. Project Overview**
The project is a real-time audience engagement application where an **admin** can create interactive polls and quizzes via a **web application**, and **participants** can respond via a **Flutter mobile app**. The system supports **live voting, word clouds, quizzes, and analytics**.

---
## **2. System Architecture**
### **Components:**
- **Frontend (Web Admin Panel)**: React.js/Next.js for managing polls/quizzes
- **Mobile App**: Flutter for participant interaction
- **Backend API**: Node.js (Express) for handling requests
- **Database**: PostgreSQL for structured data storage
- **Real-time Engine**: WebSockets (Socket.IO) for live updates
- **Authentication**: Firebase Auth or custom JWT-based login
- **Hosting**: Free services like Vercel, Firebase, or GitHub Pages

### **Architecture Diagram:**
1. Admin creates a poll via **React Web App** → Sends data to **Backend API** → Stores in **Database**
2. Participants open the **Flutter App** → Fetch questions via API
3. Live responses handled via **WebSockets** for real-time updates
4. Results displayed on the admin dashboard in **real-time**

---
## **3. Technology Stack**
### **Frontend (Admin Panel)**
- React.js or Next.js (for SSR support)
- TailwindCSS (UI Styling)
- Redux or Zustand (State Management)
- Firebase Authentication (User Management)
- WebSockets (Socket.IO for live updates)

### **Mobile App (Flutter)**
- Flutter (Dart)
- Riverpod / Provider (State Management)
- WebSockets (for real-time voting)
- Dio (API Calls)

### **Backend (API & Database)**
- Node.js (Express.js) or FastAPI (Python)
- PostgreSQL (Hosted on Free-tier options like Supabase)
- Redis (Optional, can use in-memory cache instead)
- Socket.IO (Real-time Communication)
- JWT Authentication (Custom implementation)

---
## **4. Database Schema**
### **Tables:**
#### **Users Table**
| Column     | Type        | Description             |
|------------|------------|-------------------------|
| id         | UUID       | Primary Key             |
| email      | String     | Unique email            |
| password   | String     | Hashed password         |
| role       | String     | 'admin' or 'participant'|

#### **Polls Table**
| Column     | Type        | Description             |
|------------|------------|-------------------------|
| id         | UUID       | Primary Key             |
| question   | String     | Poll Question           |
| options    | JSON       | Poll Options            |
| created_by | UUID       | Admin ID (Foreign Key)  |

#### **Responses Table**
| Column     | Type        | Description             |
|------------|------------|-------------------------|
| id         | UUID       | Primary Key             |
| poll_id    | UUID       | Poll ID (Foreign Key)   |
| user_id    | UUID       | Participant ID (Foreign Key) |
| answer     | String     | Selected Option         |

---
## **5. API Endpoints**
### **Authentication**
- `POST /api/auth/register` → Register a new user
- `POST /api/auth/login` → Authenticate user
- `POST /api/auth/logout` → Logout user

### **Poll Management**
- `POST /api/polls` → Create a new poll (Admin only)
- `GET /api/polls` → Fetch active polls
- `GET /api/polls/{id}` → Fetch a specific poll

### **Voting & Responses**
- `POST /api/responses` → Submit a vote
- `GET /api/responses/{poll_id}` → Fetch poll results

---
## **6. WebSocket Implementation**
### **Events:**
- `connect` → Establish a connection
- `newVote` → Broadcast new votes in real-time
- `updateResults` → Send updated poll results

#### **Example WebSocket Workflow:**
1. **User votes** → Emit `newVote` event
2. **Server updates database** → Broadcast `updateResults` to all connected clients

---
## **7. Deployment Guide**
### **Backend (Node.js API)**
- Deploy on **Render.com (Free-tier)** or **Railway.app**
- Use **GitHub Actions for CI/CD**

### **Web Frontend (React/Next.js)**
- Deploy on **Vercel / Netlify (Free-tier)**
- Use **GitHub Pages for static content**

### **Flutter Mobile App**
- **Android**: Publish APK via GitHub Releases or Firebase App Distribution
- **iOS**: Only local testing (as App Store requires paid membership)

---
## **8. Testing & Security Measures**
### **Testing**
- **Unit Testing**: Jest (for React), Flutter Test (for Flutter)
- **Integration Testing**: Postman, Jest
- **Load Testing**: k6 (Free open-source tool)

### **Security**
- **JWT Tokens** for API security
- **Rate Limiting** to prevent spam (Express-rate-limit)
- **CORS Policy** to restrict unauthorized access

---
## **9. Future Enhancements**
- **AI-based Sentiment Analysis** for feedback (Using Open-source models)
- **Gamification** (leaderboards, rewards)
- **Integration with Jitsi Meet (Free alternative to Zoom)**

### **Project Timeline**
| Sprint | Task | Duration |
|--------|------|----------|
| Sprint 1 | Setup & Planning | 1 Week |
| Sprint 2 | Backend API | 2 Weeks |
| Sprint 3 | Web Admin Panel | 3 Weeks |
| Sprint 4 | Flutter App | 3 Weeks |
| Sprint 5 | Testing & Bug Fixes | 2 Weeks |
| Sprint 6 | Deployment | 1 Week |

---
This document serves as a **guide for developers** to follow while building the project using only free services and tools. Let me know if you'd like additional details! 🚀

