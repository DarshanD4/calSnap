import csv
import json

csv_file = "db/nutrition.csv"
json_file = "db/food_data.json"

def to_float(value):
    try:
        return float(value)
    except:
        return 0.0

data = {}

with open(csv_file, encoding="utf-8") as f:
    reader = csv.DictReader(f)
    for row in reader:
        name = row["Dish Name"].strip().lower()

        data[name] = {
            "calories": to_float(row["Calories (kcal)"]),
            "carbohydrates": to_float(row["Carbohydrates (g)"]),
            "protein": to_float(row["Protein (g)"]),
            "fats": to_float(row["Fats (g)"]),
            "free_sugar": to_float(row["Free Sugar (g)"]),
            "fibre": to_float(row["Fibre (g)"]),
            "sodium": to_float(row["Sodium (mg)"]),
            "calcium": to_float(row["Calcium (mg)"]),
            "iron": to_float(row["Iron (mg)"]),
            "vitamin_c": to_float(row["Vitamin C (mg)"]),
            "folate": to_float(row["Folate (µg)"])
        }

with open(json_file, "w", encoding="utf-8") as f:
    json.dump(data, f, indent=4)

print("JSON created successfully → db/food_data.json")
