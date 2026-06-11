# Event App

A Flutter & Firebase based event management application developed for event creation, participant registration, and role-based access control.

## Overview

Event App allows users to register, complete their profiles, browse events, and join available events. Authorized users can create and manage events through a role-based permission system.

This project was developed to improve Flutter, Firebase, and mobile application development skills while building a real-world event management workflow.

---

## Features

### Authentication
- User registration and login
- Firebase Authentication integration
- Persistent authentication state
- Automatic session management

### User Profiles
- Profile completion flow
- Faculty, department, and class information
- Firestore-based user data management

### Event Management
- Create events
- View upcoming events
- Event details screen
- Real-time Firestore updates

### Registration System
- Join events
- Duplicate registration prevention
- Participant tracking
- Registration records stored in Firestore

### Role-Based Access Control
- Admin
- Moderator
- User

Only authorized users can create events.

### QR Ticket Workflow
- QR ticket infrastructure
- Event check-in preparation
- Registration validation system

---

## Tech Stack

### Frontend
- Flutter
- Dart
- Material 3

### Backend & Database
- Firebase Authentication
- Cloud Firestore
- Firebase Core

### Tools
- Git
- GitHub
- Android Studio
- VS Code
- Xcode

---

## Project Structure

```text
lib/
├── models/
├── services/
├── screens/
├── widgets/
├── auth_gate.dart
├── firebase_options.dart
└── main.dart
```

---

## Firebase Collections

### users

Stores user profile information.

Fields:

- fullName
- email
- role
- faculty
- department
- grade
- profileCompleted

### events

Stores event information.

Fields:

- title
- description
- location
- date
- createdBy
- createdByRole
- createdAt
- isActive

### registrations

Stores event participation records.

Fields:

- eventId
- userId
- userName
- userEmail
- joinedAt
- checkedIn

---

## Application Flow

1. User opens the application.
2. Authentication state is checked.
3. User logs in or registers.
4. Profile completion is verified.
5. Events are loaded from Firestore.
6. User joins an event.
7. Admin or moderator can create new events.

## Future Improvements

- Push notifications
- Dark mode support
- Improved state management

---

## Learning Outcomes

This project helped me gain hands-on experience with:

- Flutter widget architecture
- Firebase Authentication
- Cloud Firestore
- Real-time data streams
- Role-based authorization
- Mobile application development lifecycle
- Git and GitHub workflow

---

## Author

**Ebranur Özbalık**

Computer Engineering Student  
Flutter Developer

GitHub:
https://github.com/EbranurOzbalik

LinkedIn:
https://www.linkedin.com/in/ebranur-özbalık/
