AI-powered food insights, calorie lookup, and personal nutrition tracking.

CalSnap is a modern Flutter + Flask application that lets users:

Search for foods and get instant nutrition values

Take photos of foods and upload for analysis

Add custom foods with photos

Save meals and track calorie history

Favorite frequently used foods

Use autocomplete for fast food search

Get simple rule-based AI meal suggestions

Built to be fast, simple, and future-ready for full AI integration.

🚀 Features
🔍 1. Search Nutrition

Type any food name and instantly view:

Calories

Carbs

Protein

Fats

Micronutrients

With a beautiful Google-style autocomplete dropdown.

📸 2. Photo-Based Food Input

Take a photo using your device camera (Flutter image_picker) and upload it to the backend.

🧑‍🍳 3. Create Your Own Foods

If a food is not found:

Give it a name

Add carbs, fats, protein, calories

Upload 3–4 photos

Saved permanently in database

Available instantly in autocomplete + lookup

🕒 4. Meal History Tracking

Every lookup can be saved as:

Meal item

Quantity

Timestamp

Total calories

Stored in /data/meals.json.

⭐ 5. Favorites

Add commonly eaten foods to favorites for quick access.

🤖 6. AI Meal Suggestions

Simple rule-based engine gives:

Weight loss meal plans

Muscle gain meals

Maintenance meals

🧱 Tech Stack
Frontend (Flutter)

Flutter 3+

Dart

Material 3 UI

image_picker

http

Overlay-based Autocomplete UI

Modal bottom sheets

Clean & modern UI

Backend (Flask)

Python 3

Flask

JSON-based database

Multipart image upload

Custom food creation

Meal + favorites storage

Autocomplete + fuzzy search

📁 Project Structure
calsnap/
 ┣ backend/
 ┃ ┣ app.py                 # Flask server
 ┃ ┣ data/                  # JSON storage (meals, favs, custom foods)
 ┃ ┣ uploads/               # Uploaded food & custom images
 ┃ ┗ db/food_data.json      # Main nutrition database
 ┣ flutter_app/
 ┃ ┗ lib/
 ┃   ┗ main.dart            # Full Flutter UI
 ┗ README.md

⚙️ Backend Setup
1. Create virtual environment
cd backend
python -m venv .venv
.venv\Scripts\activate   # Windows

2. Install dependencies
pip install flask werkzeug

3. Run the server
python app.py


Runs on:

http://127.0.0.1:5000
http://10.0.2.2:5000  # Android emulator

📱 Flutter Setup
1. Install dependencies
flutter pub get

2. Run the app
flutter run


Choose:

Chrome
or

Android Emulator
or

Windows

🔌 API Endpoints
🔹 Search

GET /autocomplete?query=rice
GET /lookup?name=rice&qty_g=150

🔹 Create custom food

POST /food/create

Fields:

name

calories

protein

carbs

fats

images[]

🔹 Upload photo

POST /upload

🔹 Meal operations

POST /meal/add

GET /meal/list

🔹 Favorites

POST /fav/add

GET /fav/list

POST /fav/remove

🔹 AI suggestions

POST /ai/suggest

🏗️ Future Roadmap

AI-based calorie estimation from photo (MobileNet / EfficientNet)

Automatic food detection

OCR for packaged foods

Barcode scanning

Weekly calorie insights dashboard

Google login + cloud sync

Personalized diet recommendation engine

🤝 Contributing

Pull requests are welcome!
If you want help adding ML models or cloud sync, feel free to DM.

⭐ Support

If you like this project, give the repo a star ⭐ on GitHub!