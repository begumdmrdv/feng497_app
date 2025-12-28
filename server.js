const express = require("express");
const cors = require("cors");
const fs = require("fs");

const app = express();
app.use(cors());
app.use(express.json());

const DATA_FILE = "data.json";

// Risk değerlendirme fonksiyonu
function evaluateRisk(glucose) {
  if (glucose < 100) return { risk: "Normal", advice: "Keep a healthy lifestyle." };
  if (glucose < 140) return { risk: "Prediabetes", advice: "Pay attention to diet and exercise." };
  return { risk: "High Risk", advice: "Consult a doctor." };
}

// Data yükleme
function loadData() {
  if (!fs.existsSync(DATA_FILE)) return [];
  const raw = fs.readFileSync(DATA_FILE, "utf-8");
  return JSON.parse(raw);
}

// Data kaydetme
function saveData(data) {
  fs.writeFileSync(DATA_FILE, JSON.stringify(data, null, 2));
}

// Ölçüm ekleme endpoint
app.post("/measurements", (req, res) => {
  const glucose = Number(req.body.glucose);
  if (isNaN(glucose)) return res.status(400).json({ error: "Glucose must be a number" });

  const data = loadData();
  const average = data.length
    ? (data.reduce((sum, d) => sum + d.glucose, 0) + glucose) / 
(data.length + 1)
    : glucose;

  const riskInfo = evaluateRisk(glucose);

  const newEntry = {
    id: Date.now(),
    glucose: glucose,
    device_id: "UNKNOWN",
    average: Math.round(average),
    predicted_next: Math.round(average + 20),
    trend: data.length && glucose > data[data.length - 1].glucose ? "up" : 
"stable",
    risk: riskInfo.risk,
    advice: riskInfo.advice,
    alert: riskInfo.risk === "High Risk",
    confidence: 0.6,
    timestamp: new Date().toISOString()
  };

  data.push(newEntry);
  saveData(data);

  res.json(newEntry);
});

// Tüm ölçümleri listeleme endpoint
app.get("/measurements", (req, res) => {
  const data = loadData();
  res.json(data);
});

// Server başlatma
app.listen(4000, "0.0.0.0", () => {
  console.log("🚀 AI Backend is running at http://0.0.0.0:4000");
});
