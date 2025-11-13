from flask import Flask, request, jsonify
from werkzeug.utils import secure_filename
import os
import json
import time
from pathlib import Path

# Initialize Flask app
app = Flask(__name__)

# --------------------------
# CONFIG
# --------------------------
UPLOAD_FOLDER = "uploads"
app.config['UPLOAD_FOLDER'] = UPLOAD_FOLDER
os.makedirs(UPLOAD_FOLDER, exist_ok=True)

DATA_DIR = Path("data")
DATA_DIR.mkdir(exist_ok=True)

MEALS_FILE = DATA_DIR / "meals.json"
FAVS_FILE = DATA_DIR / "favs.json"
PHOTOS_FILE = DATA_DIR / "photos.json"
CUSTOM_FILE = DATA_DIR / "custom_foods.json"

# --------------------------
# LOAD MAIN FOOD DATABASE
# --------------------------
try:
    with open("db/food_data.json", encoding="utf-8") as f:
        CAL_DB = json.load(f)
except:
    CAL_DB = {}

# --------------------------
# LOAD CUSTOM FOODS ON STARTUP
# --------------------------
if CUSTOM_FILE.exists():
    try:
        custom_foods = json.loads(CUSTOM_FILE.read_text(encoding="utf-8"))
        CAL_DB.update(custom_foods)
        print("Custom foods loaded:", len(custom_foods))
    except:
        print("Error loading custom foods")

# --------------------------
# HELPERS
# --------------------------
def _read_json(path, default):
    if not path.exists():
        return default
    try:
        return json.loads(path.read_text(encoding="utf-8"))
    except:
        return default

def _write_json(path, obj):
    path.write_text(json.dumps(obj, indent=2), encoding="utf-8")


# --------------------------
# ROUTES
# --------------------------

@app.route("/health")
def health():
    return jsonify({"status": "ok"})


# --------------------------
# LOOKUP
# --------------------------
@app.route("/lookup")
def lookup():
    name = request.args.get("name", "").strip().lower()
    qty = float(request.args.get("qty_g", "100") or 100)

    # Exact match
    if name in CAL_DB:
        item = CAL_DB[name]
        scale = qty / 100.0

        result = {
            "name": name,
            "quantity_g": qty,
            "calories": round(item["calories"] * scale, 2),
            "carbohydrates": round(item["carbohydrates"] * scale, 2),
            "protein": round(item["protein"] * scale, 2),
            "fats": round(item["fats"] * scale, 2),
            "free_sugar": round(item["free_sugar"] * scale, 2),
            "fibre": round(item["fibre"] * scale, 2),
            "sodium": round(item["sodium"] * scale, 2),
            "calcium": round(item["calcium"] * scale, 2),
            "iron": round(item["iron"] * scale, 2),
            "vitamin_c": round(item["vitamin_c"] * scale, 2),
            "folate": round(item["folate"] * scale, 2),
        }
        return jsonify(result)

    # Fuzzy search fallback
    matches = [
        food for food in CAL_DB.keys()
        if name in food.lower()
    ]

    return jsonify({"matches": matches[:10], "error": "not_found"})


# --------------------------
# AUTOCOMPLETE
# --------------------------
@app.route("/autocomplete")
def autocomplete():
    query = request.args.get("query", "").strip().lower()

    if not query:
        return jsonify([])

    matches = [
        food for food in CAL_DB.keys()
        if query in food.lower()
    ]

    return jsonify(matches[:10])


# --------------------------
# MEAL MANAGEMENT
# --------------------------
@app.route("/meal/add", methods=["POST"])
def add_meal():
    payload = request.get_json(force=True, silent=True)
    if not payload or "items" not in payload:
        return jsonify({"error": "bad_request"}), 400

    meals = _read_json(MEALS_FILE, [])

    entry = {
        "id": int(time.time() * 1000),
        "items": payload["items"],
        "total_calories": round(sum(it.get("calories", 0) for it in payload["items"]), 2),
        "timestamp": payload.get("timestamp", int(time.time())),
        "note": payload.get("note", "")
    }

    meals.insert(0, entry)
    _write_json(MEALS_FILE, meals)

    return jsonify({"ok": True, "entry": entry})


@app.route("/meal/list", methods=["GET"])
def list_meals():
    meals = _read_json(MEALS_FILE, [])
    return jsonify(meals)


# --------------------------
# FAVORITES
# --------------------------
@app.route("/fav/add", methods=["POST"])
def add_fav():
    payload = request.get_json(force=True, silent=True)
    if not payload or "name" not in payload:
        return jsonify({"error": "bad_request"}), 400

    favs = _read_json(FAVS_FILE, [])
    name = payload["name"].strip().lower()

    if name not in favs:
        favs.insert(0, name)

    _write_json(FAVS_FILE, favs)
    return jsonify({"ok": True, "favs": favs})


@app.route("/fav/list", methods=["GET"])
def list_favs():
    favs = _read_json(FAVS_FILE, [])
    return jsonify(favs)


@app.route("/fav/remove", methods=["POST"])
def remove_fav():
    payload = request.get_json(force=True, silent=True)
    if not payload or "name" not in payload:
        return jsonify({"error": "bad_request"}), 400

    favs = _read_json(FAVS_FILE, [])
    name = payload["name"].strip().lower()

    favs = [f for f in favs if f != name]
    _write_json(FAVS_FILE, favs)

    return jsonify({"ok": True, "favs": favs})


# --------------------------
# PHOTO / IMAGE UPLOAD
# --------------------------
@app.route("/upload", methods=["POST"])
def upload():
    if 'image' not in request.files:
        return jsonify({"error": "no_image"}), 400

    f = request.files['image']
    filename = secure_filename(f.filename)
    path = os.path.join(app.config['UPLOAD_FOLDER'], filename)
    f.save(path)

    return jsonify({"saved_as": path})


# --------------------------
# CREATE CUSTOM FOOD
# --------------------------
@app.route("/food/create", methods=["POST"])
def create_food():
    name = request.form.get("name", "").strip().lower()
    if not name:
        return jsonify({"error": "name_required"}), 400

    calories = float(request.form.get("calories", "0") or 0)
    protein  = float(request.form.get("protein", "0") or 0)
    carbs    = float(request.form.get("carbs", "0") or 0)
    fats     = float(request.form.get("fats", "0") or 0)

    foods = _read_json(CUSTOM_FILE, {})

    image_paths = []
    if "images" in request.files:
        files = request.files.getlist("images")
        for f in files[:4]:
            filename = f"custom_{int(time.time()*1000)}_{f.filename}"
            save_path = os.path.join(app.config["UPLOAD_FOLDER"], filename)
            f.save(save_path)
            image_paths.append(save_path)

    foods[name] = {
        "calories": calories,
        "protein": protein,
        "carbohydrates": carbs,
        "fats": fats,
        "free_sugar": 0,
        "fibre": 0,
        "sodium": 0,
        "calcium": 0,
        "iron": 0,
        "vitamin_c": 0,
        "folate": 0,
        "images": image_paths
    }

    _write_json(CUSTOM_FILE, foods)

    # merge into CAL_DB
    CAL_DB[name] = foods[name]

    return jsonify({"ok": True, "food": foods[name]})


# --------------------------
# AI (RULE BASED SUGGESTIONS)
# --------------------------
@app.route("/ai/suggest", methods=["POST"])
def ai_suggest():
    payload = request.get_json(force=True, silent=True) or {}
    goal = payload.get("goal", "maintain")

    if goal == "lose_weight":
        plan = [
            {"meal": "Breakfast", "items": ["oats", "banana"]},
            {"meal": "Lunch", "items": ["brown rice", "grilled chicken"]},
            {"meal": "Dinner", "items": ["roti", "dal"]}
        ]
    elif goal == "gain_muscle":
        plan = [
            {"meal": "Breakfast", "items": ["eggs", "milk"]},
            {"meal": "Lunch", "items": ["rice", "paneer"]},
            {"meal": "Dinner", "items": ["roti", "lentils"]}
        ]
    else:
        plan = [
            {"meal": "Breakfast", "items": ["poha"]},
            {"meal": "Lunch", "items": ["rice", "dal"]},
            {"meal": "Dinner", "items": ["roti", "sabzi"]}
        ]

    return jsonify({"suggestions": plan})


# --------------------------
# RUN SERVER
# --------------------------
if __name__ == "__main__":
    app.run(host="0.0.0.0", port=5000, debug=True)
