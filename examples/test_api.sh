#!/bin/bash
# Test the model server API

BASE_URL=${1:-http://localhost:8080}

echo "🧪 Testing Model Server API"
echo "Base URL: $BASE_URL"
echo ""

# Test 1: Health check
echo "1️⃣  Testing /health endpoint..."
response=$(curl -s "$BASE_URL/health")
echo "Response: $response"
echo ""

# Test 2: Prediction
echo "2️⃣  Testing /predict endpoint..."
echo "Input: Iris flower with features [5.1, 3.5, 1.4, 0.2]"
response=$(curl -s -X POST "$BASE_URL/predict" \
  -H "Content-Type: application/json" \
  -d '{"features": [5.1, 3.5, 1.4, 0.2]}')
echo "Response: $response"
echo ""

# Test 3: Different prediction
echo "3️⃣  Testing another prediction..."
echo "Input: Iris flower with features [6.7, 3.1, 5.6, 2.4]"
response=$(curl -s -X POST "$BASE_URL/predict" \
  -H "Content-Type: application/json" \
  -d '{"features": [6.7, 3.1, 5.6, 2.4]}')
echo "Response: $response"
echo ""

# Test 4: Attestations
echo "4️⃣  Testing /attestations endpoint..."
response=$(curl -s "$BASE_URL/attestations")
echo "Response: $response" | python3 -m json.tool 2>/dev/null || echo "$response"
echo ""

echo "✅ API tests complete"
