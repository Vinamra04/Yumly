# 🍳 Yumly – Your AI-Powered Recipe & Meal Planning App

Yumly is a smart, cross-platform mobile app that transforms your cooking experience. Powered by Google Gemini AI and built with Flutter, Yumly helps you discover, generate, and organize recipes, plan meals, and manage your kitchen inventory—all in one place.

---

## 🚀 Features

- **AI Recipe Generation:**  
  Instantly generate creative, personalized recipes using Google Gemini AI. Just enter your ingredients or a prompt and let Yumly do the rest!

- **Smart Recipe Search:**  
  Search for recipes by dish name or available ingredients. Each recipe comes with step-by-step instructions and nutritional info.

- **Meal Planning:**  
  Plan your meals for the week with an intuitive meal planner. Assign recipes to specific days and meals, and generate a grocery list based on your plan.

- **Inventory Management:**  
  Track your kitchen inventory by categories (vegetables, fruits, dairy, meat, grains, spices, etc.). Get notified about expiring ingredients and reduce food waste. Use your inventory to get recipe suggestions for what you can cook right now.

- **YumlyBot – AI Cooking Assistant:**  
  Chat with YumlyBot for instant cooking tips, ingredient substitutions, or meal ideas—powered by AI.

- **Personalized User Experience:**  
  Secure authentication, user profiles, saved favorites, and personalized suggestions.

- **Light & Dark Mode:**  
  Seamless theme switching for comfortable viewing day or night.

- **Settings & Customization:**  
  Manage your account, preferences, and app appearance. View app version and developer info.

- **Real-Time Sync & Cloud Backup:**  
  All your data is securely synced and backed up with Firebase, so you can access it across devices.

---

## 📱 Screenshots

<div align="center">

### 🏠 Home Screen
<p align="center">
  <img src="screenshots/homepage_1.png" width="250" alt="Homepage 1"/>
  <img src="screenshots/homepage_2.png" width="250" alt="Homepage 2"/>
  <img src="screenshots/dark_mode_home.png" width="250" alt="Dark Mode Home"/>
</p>

### 🍽️ Recipe & Meal Planning
<p align="center">
  <img src="screenshots/recipes_screen.png" width="250" alt="Recipes Screen"/>
  <img src="screenshots/chatbot.png" width="250" alt="AI Chatbot"/>
  <img src="screenshots/meal_plan.png" width="250" alt="Meal Plan"/>
</p>

### 📦 Inventory & Settings
<p align="center">
  <img src="screenshots/inventory.png" width="250" alt="Inventory Management"/>
  <img src="screenshots/settings.png" width="250" alt="Settings"/>
</p>

</div>

---

## 🛠️ Tech Stack

- **Flutter** – Cross-platform UI toolkit for beautiful native apps
- **Dart** – Programming language optimized for UI development
- **Google Gemini AI** – Advanced AI for recipe generation and intelligent chat
- **Firebase** – Backend services including:
  - Authentication (Email/Password + Google Sign-In)
  - Firestore Database for real-time data sync
  - Cloud Storage for media files
  - Security rules for data protection

---

## ⚡ Getting Started

### Prerequisites

- [Flutter SDK](https://flutter.dev/docs/get-started/install) (3.7.2 or higher)
- [Dart SDK](https://dart.dev/get-dart)
- [Firebase CLI](https://firebase.google.com/docs/cli)
- A valid Google Gemini AI API key from [Google AI Studio](https://aistudio.google.com/app/apikey)

### Installation & Setup

1. **Clone the repository:**
   ```bash
   git clone https://github.com/yourusername/yumly.git
   cd yumly
   ```

2. **Install dependencies:**
   ```bash
   flutter pub get
   ```

3. **Configure Environment Variables:**
   - Copy `.env.example` to `.env`:
     ```bash
     cp .env.example .env
     ```
   - Add your Gemini AI API key to the `.env` file:
     ```
     GEMINI_API_KEY=your_actual_api_key_here
     ```

4. **Configure Firebase:**
   - Create a new Firebase project at [Firebase Console](https://console.firebase.google.com/)
   - Add your `google-services.json` (Android) to `android/app/`
   - Add your `GoogleService-Info.plist` (iOS) to `ios/Runner/`
   - Update `lib/firebase_options.dart` with your project configuration

5. **Set up Firestore Security Rules:**
   ```bash
   firebase login
   firebase use your-project-id
   firebase deploy --only firestore:rules
   ```

6. **Run the app:**
   ```bash
   flutter run
   ```

---

## 🔧 Configuration

### Firebase Setup
1. Enable Authentication with Email/Password and Google Sign-In
2. Create a Firestore database in production mode
3. Deploy the included security rules for proper data access control

### API Keys
- Keep your `.env` file secure and never commit it to version control
- The `.env` file is already included in `.gitignore`
- Other developers should copy `.env.example` to `.env` and add their own API keys

---

## ✨ Usage

1. **Getting Started:**
   - Sign up with email/password or Google Sign-In
   - Complete your profile setup

2. **Managing Inventory:**
   - Add ingredients to your kitchen inventory
   - Set expiration dates to reduce food waste
   - Get recipe suggestions based on available ingredients

3. **Discovering Recipes:**
   - Generate AI-powered recipes with custom prompts
   - Search for recipes by name or ingredients
   - Save your favorite recipes for quick access

4. **Meal Planning:**
   - Plan meals for the week using the calendar interface
   - Generate shopping lists based on your meal plans
   - Track nutritional information

5. **AI Assistant:**
   - Chat with YumlyBot for cooking tips and substitutions
   - Get personalized meal suggestions
   - Ask questions about recipes and cooking techniques

6. **Customization:**
   - Switch between light and dark themes
   - Manage account settings and preferences
   - View app information and version details

---

## 🏗️ Project Structure

```
lib/
├── main.dart                 # App entry point
├── firebase_options.dart     # Firebase configuration
├── models/                   # Data models
│   ├── inventory_item.dart
│   └── meal_plan.dart
├── screens/                  # UI screens
│   ├── auth_screen.dart
│   ├── home_screen.dart
│   ├── recipe_screen.dart
│   ├── mealplan_screen.dart
│   ├── inventory_screen.dart
│   ├── settings_screen.dart
│   └── user_name_screen.dart
├── services/                 # Business logic
│   ├── gemini_service.dart
│   ├── inventory_service.dart
│   └── meal_plan_service.dart
└── utils/                    # Utilities
    └── theme_transition.dart
```

---

## 🤝 Contributing

We welcome contributions! Please follow these steps:

1. Fork the repository
2. Create a feature branch (`git checkout -b feature/amazing-feature`)
3. Commit your changes (`git commit -m 'Add some amazing feature'`)
4. Push to the branch (`git push origin feature/amazing-feature`)
5. Open a Pull Request

---

## 📄 License

This project is licensed under the MIT License. See the [LICENSE](LICENSE) file for details.

---

## 🙌 Acknowledgements

- [Flutter](https://flutter.dev/) - For the amazing cross-platform framework
- [Google Gemini AI](https://aistudio.google.com/) - For powerful AI capabilities
- [Firebase](https://firebase.google.com/) - For reliable backend services
- [Google Fonts](https://fonts.google.com/) - For beautiful typography
- All open-source contributors and the developer community!

---

## 📬 Contact & Support

For questions, feedback, or contributions:
- Open an issue on GitHub
- Contact the development team
- Check out our documentation

---

## 🔒 Security

- All API keys are stored securely using environment variables
- Firebase security rules ensure data privacy
- User authentication is handled by Firebase Auth
- All data is encrypted in transit and at rest

---

> **Yumly – Making your kitchen smarter, one recipe at a time! 🍳✨**
