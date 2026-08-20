FROM python:3.11-slim

WORKDIR /app

COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

COPY app.py .

# ไม่ต้องใช้ persistent disk/volume แล้ว เพราะข้อมูล License ทั้งหมดเก็บอยู่ใน
# PostgreSQL ภายนอก (ผ่าน environment variable DATABASE_URL ที่ต้องตั้งตอนรัน)
# ดู README.md หัวข้อ "ตั้งค่าฐานข้อมูล PostgreSQL" สำหรับวิธีตั้งค่า

EXPOSE 8000

CMD ["uvicorn", "app:app", "--host", "0.0.0.0", "--port", "8000"]
