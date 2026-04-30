# Step 1: Python 3.11 ka chhota base image lo
FROM python:3.11-slim

# Step 2: container ke andar /app folder banao aur usme kaam karo
WORKDIR /app

# Step 3: pehle sirf requirements.txt copy karo (cache ke liye)
COPY requirements.txt .

# Step 4: saare Python packages install karo
RUN pip install --no-cache-dir -r requirements.txt

# Step 5: app ka code copy karo
COPY app/ ./app/

# Step 6: container ka port 8000 expose karo
EXPOSE 8000

# Step 7: container start hone par yeh command chalegi
CMD ["uvicorn", "app.main:app", "--host", "0.0.0.0", "--port", "8000"]
