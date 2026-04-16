<p align="center">
  <img src="https://capsule-render.vercel.app/api?type=waving&height=220&text=Ride%20Match&fontAlign=50&fontAlignY=40&color=0:0ea5e9,100:22c55e&fontColor=ffffff&animation=fadeIn" alt="Ride Match Banner" />
</p>

<p align="center">
  <img src="https://readme-typing-svg.demolab.com?font=Inter&weight=600&size=24&pause=1000&color=22C55E&center=true&vCenter=true&width=720&lines=Smart+Ride+Matching;Real-time+Chat+%26+Location+Tracking;Flutter+%2B+Node.js+%2B+MongoDB" alt="Typing animation" />
</p>

<p align="center">
  <a href="https://flutter.dev"><img src="https://img.shields.io/badge/Flutter-02569B?style=for-the-badge&logo=flutter&logoColor=white" alt="Flutter" /></a>
  <a href="https://nodejs.org"><img src="https://img.shields.io/badge/Node.js-339933?style=for-the-badge&logo=nodedotjs&logoColor=white" alt="Node.js" /></a>
  <a href="https://www.mongodb.com/"><img src="https://img.shields.io/badge/MongoDB-47A248?style=for-the-badge&logo=mongodb&logoColor=white" alt="MongoDB" /></a>
  <img src="https://img.shields.io/github/stars/Va09joshi/Ride-Match?style=for-the-badge" alt="Stars" />
  <img src="https://img.shields.io/github/last-commit/Va09joshi/Ride-Match?style=for-the-badge" alt="Last Commit" />
</p>

---

## 🚗 Overview

**Ride Match** is a full-stack ridesharing app that connects drivers and passengers for affordable and efficient travel.

### ✨ Core Highlights
- 🔐 JWT-based authentication
- 🗺️ Live location + map experience
- 💬 Real-time chat using Socket.IO
- 💳 Payment integration support
- ⭐ Ratings and profile management

---

## 🧰 Tech Stack

### Frontend
- Flutter (Dart)
- Google Maps integration
- Socket.IO client

### Backend
- Node.js + Express
- MongoDB + Mongoose
- Socket.IO

---

## 📁 Project Structure

```text
Ride-Match/
├── backend/
│   ├── server.js
│   ├── controllers/
│   ├── models/
│   ├── routes/
│   └── middleware/
└── frontend/
    ├── lib/
    ├── assets/
    ├── android/
    └── ios/
```

---

## ⚙️ Getting Started

### Prerequisites
- Node.js 16+
- Flutter 3+
- MongoDB

### 1) Clone Repository
```bash
git clone https://github.com/Va09joshi/Ride-Match.git
cd Ride-Match
```

### 2) Setup Backend
```bash
cd backend
npm install
```

Create `backend/.env`:
```env
MONGO_URI=your_mongodb_connection_string
JWT_SECRET=your_jwt_secret
PORT=5000
NODE_ENV=development
IMGBB_API_KEY=your_imgbb_api_key
```

Run backend:
```bash
npm start
```

### 3) Setup Frontend
```bash
cd ../frontend
flutter pub get
flutter run
```

---

## 🤝 Contributing

1. Fork the repository
2. Create a branch: `git checkout -b feature/your-feature`
3. Commit changes: `git commit -m "feat: add your feature"`
4. Push branch and open a Pull Request

---

## 👤 Author

**Vaibhav Joshi**
- GitHub: [@Va09joshi](https://github.com/Va09joshi)
- Repository: [Ride-Match](https://github.com/Va09joshi/Ride-Match)

---

<p align="center">
  <img src="https://capsule-render.vercel.app/api?type=waving&section=footer&height=120&color=0:22c55e,100:0ea5e9" alt="Footer wave" />
</p>
