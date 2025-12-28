// GERÇEK ML — Linear Regression (Node uyumlu)

function predictNext(values) {
  if (values.length < 2) return values[values.length - 1];

  const n = values.length;
  let sumX = 0,
    sumY = 0,
    sumXY = 0,
    sumXX = 0;

  for (let i = 0; i < n; i++) {
    sumX += i;
    sumY += values[i];
    sumXY += i * values[i];
    sumXX += i * i;
  }

  const slope =
    (n * sumXY - sumX * sumY) / (n * sumXX - sumX * sumX);
  const intercept = (sumY - slope * sumX) / n;

  return Math.round(slope * n + intercept);
}

module.exports = { predictNext };

