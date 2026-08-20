# License Server — คู่มือ Deploy

เซิร์ฟเวอร์นี้เป็น FastAPI app ที่เก็บข้อมูล License ทั้งหมดใน **PostgreSQL** (ไม่ใช้ SQLite
ไฟล์เดี่ยว) เพื่อให้ข้อมูลอยู่ถาวร ไม่หายเมื่อเซิร์ฟเวอร์ redeploy/restart/spin down

---

## ขั้นที่ 1: ตั้งค่าฐานข้อมูล PostgreSQL (ใช้ Supabase — ฟรีถาวร)

1. สมัครบัญชีที่ https://supabase.com (ฟรี ไม่ต้องผูกบัตร)
2. กด **New Project** ตั้งชื่ออะไรก็ได้ เลือก Region ใกล้ผู้ใช้งาน (เช่น Singapore)
   ตั้งรหัสผ่านฐานข้อมูล **จดไว้ให้ดี** จะใช้ในขั้นตอนถัดไป
3. รอสักครู่ให้ project สร้างเสร็จ (~2 นาที)
4. กดปุ่ม **Connect** ที่แถบด้านบนของหน้า project
5. เลือกแท็บ **Session pooler** (สำคัญ — ต้องใช้ตัวนี้ ไม่ใช่ Direct connection เพราะ
   เซิร์ฟเวอร์อย่าง Render มักอยู่บนเครือข่าย IPv4 เท่านั้น ส่วน Direct connection ของ
   Supabase ใช้ IPv6 เป็นหลัก)
6. คัดลอก connection string ที่ได้ หน้าตาประมาณนี้:
   ```
   postgresql://postgres.xxxxxxxxxxxx:[YOUR-PASSWORD]@aws-0-ap-southeast-1.pooler.supabase.com:5432/postgres
   ```
7. แทนที่ `[YOUR-PASSWORD]` ด้วยรหัสผ่านที่ตั้งไว้ในขั้นตอนที่ 2 — นี่คือค่าที่จะใช้เป็น
   `DATABASE_URL` ในขั้นตอนถัดไป

---

## ขั้นที่ 2: Deploy เซิร์ฟเวอร์ (เลือกทางใดทางหนึ่ง)

### ทางเลือกที่ 1: Render.com (แนะนำ — มี Free Tier, ตั้งค่าไม่กี่คลิก)

1. สร้าง repo GitHub แล้วอัปโหลดโฟลเดอร์ `server/` (ไฟล์ `app.py`, `requirements.txt`) ขึ้นไป
2. ไปที่ https://render.com -> New -> Web Service -> เชื่อมกับ repo ของคุณ
3. ตั้งค่า:
   - **Build Command**: `pip install -r requirements.txt`
   - **Start Command**: `uvicorn app:app --host 0.0.0.0 --port $PORT`
4. ไปที่แท็บ **Environment** เพิ่มตัวแปร:
   - `ADMIN_TOKEN` = รหัสลับที่คุณตั้งเอง (ยาวๆ สุ่มๆ เก็บไว้ให้ดี ห้ามบอกใคร)
   - `DATABASE_URL` = connection string จากขั้นที่ 1 (ต้องมี `?sslmode=require` ต่อท้ายด้วย
     ถ้า Supabase ไม่ได้ใส่ให้อัตโนมัติ)
5. กด Deploy รอสักครู่ จะได้ URL เช่น `https://your-app.onrender.com`
6. ใช้ URL นี้ใส่ใน `LICENSE_SERVER_URL` ทั้งฝั่ง client (`license_client.py`) และตอนรัน `admin_cli.py`

> ⚠️ Free tier ของ Render จะ "หลับ" เมื่อไม่มีการใช้งาน แล้วปลุกตื่นช้า (~30-60 วิ) ตอนมีคน
> เรียกครั้งแรก — แต่ตอนนี้ **ข้อมูล License จะไม่หายแล้ว** เพราะเก็บอยู่ใน Supabase
> ไม่ใช่ในตัวเซิร์ฟเวอร์เอง ถ้าอยากให้ตอบสนองเร็วตลอดเวลา ควรอัปเป็นแพ็กเกจเสียเงินระดับล่างสุด

### ทางเลือกที่ 2: Railway.app

1. อัปโหลดโฟลเดอร์ `server/` ขึ้น GitHub เหมือนทางเลือกที่ 1
2. ไปที่ https://railway.app -> New Project -> Deploy from GitHub repo
3. Railway จะ detect Python เอง ให้ตั้ง Start Command เป็น:
   `uvicorn app:app --host 0.0.0.0 --port $PORT`
4. เพิ่ม Environment Variable `ADMIN_TOKEN` และ `DATABASE_URL` เหมือนข้างบน
5. Deploy แล้วจะได้ URL มาใช้งาน

### ทางเลือกที่ 3: VPS ของตัวเอง (DigitalOcean, Vultr, ฯลฯ) ด้วย Docker

```bash
# บนเครื่อง VPS
git clone <your-repo-url>
cd server

docker build -t license-server .
docker run -d \
  --name license-server \
  -p 8000:8000 \
  -e ADMIN_TOKEN="your-secret-admin-token" \
  -e DATABASE_URL="postgresql://postgres.xxxx:PASSWORD@aws-0-xxxx.pooler.supabase.com:5432/postgres" \
  --restart unless-stopped \
  license-server
```

จากนั้นตั้ง Nginx/Caddy reverse proxy + SSL (แนะนำ Caddy เพราะออก HTTPS ให้อัตโนมัติ)
เพื่อให้เรียกผ่าน `https://license.yourdomain.com` แทน IP ตรงๆ

---

## ทดสอบว่าเซิร์ฟเวอร์ทำงาน

```bash
curl https://your-server-url.example.com/
# ควรได้: {"status":"ok","service":"cookierun-bot-license-server"}
```

ถ้าเซิร์ฟเวอร์ start ไม่ขึ้นเลย (error ตั้งแต่ log แรก) ให้เช็คว่าใส่ `DATABASE_URL`
ถูกต้องหรือยัง เป็นสาเหตุที่พบบ่อยที่สุด

## หน้าขาย/ดาวน์โหลดสำหรับลูกค้า (`/shop`)

เปิดเบราว์เซอร์ไปที่:

```
https://your-server-url.example.com/shop
```

เป็นหน้า Landing Page พร้อมใช้ มีปุ่มดาวน์โหลดโปรแกรม, ราคา, ขั้นตอนใช้งาน, และ FAQ
(รวมคำเตือนเรื่อง Antivirus + Disclaimer ความเสี่ยงเรื่อง ToS ของเกม) ให้ส่งลิงก์นี้ตรงๆ
ให้ลูกค้าได้เลย

### ⚠️ ต้องแก้ก่อนใช้งานจริง

เปิดไฟล์ `app.py` หาคำว่า `DOWNLOAD_URL` และ `FACEBOOK_PAGE_URL` ในตัวแปร `SHOP_HTML`
(อยู่ในส่วน `<script>` ท้ายไฟล์ HTML) แก้เป็นค่าจริง:

```javascript
const DOWNLOAD_URL = "https://github.com/YOUR-USERNAME/YOUR-REPO/releases/latest";
const FACEBOOK_PAGE_URL = "https://facebook.com/YOUR-PAGE-HERE";
```

และแก้ราคาที่ยังเป็น placeholder (`฿XXX`, `฿X,XXX`) ในส่วน `<section id="pricing">`
ให้เป็นราคาจริงที่จะขาย

### แนะนำ: ใช้ GitHub Releases เก็บไฟล์ .exe

วิธีที่ง่ายและฟรีที่สุดสำหรับโฮสต์ไฟล์ .exe ให้ลูกค้าดาวน์โหลด:

1. สร้าง GitHub repo (จะ public หรือ private ก็ได้)
2. ไปที่แท็บ **Releases** ของ repo → **Create a new release**
3. ตั้ง tag เช่น `v1.0.0` แล้วลาก ไฟล์ `.zip` ที่มี `.exe` + `assets/` ไปวางในช่อง attach
4. Publish release — จะได้ลิงก์ดาวน์โหลดถาวรแบบ
   `https://github.com/user/repo/releases/latest/download/CookieRunAutoGo.zip`
5. เอาลิงก์นี้ไปใส่ใน `DOWNLOAD_URL` ด้านบน

ครั้งต่อไปที่ปล่อยเวอร์ชันใหม่ แค่สร้าง Release ใหม่ (tag ใหม่) ลิงก์ `/releases/latest`
จะชี้ไปตัวล่าสุดให้เองอัตโนมัติ ไม่ต้องแก้ `DOWNLOAD_URL` ซ้ำทุกครั้ง

### แนะนำเพิ่ม: แจกเป็น Installer แทนไฟล์ .zip

แทนที่จะแจกไฟล์ `.zip` ที่มี `.exe` + `assets/` แยกกัน (เสี่ยงลูกค้าลืมวาง assets/ ไว้ข้างๆ)
แนะนำให้ทำเป็น **Installer** (`.exe` ตัวเดียวที่ติดตั้งให้ครบทุกอย่างอัตโนมัติ) แทน:

1. รัน `build_windows.bat` ตามปกติก่อน ให้ได้โฟลเดอร์ `dist\` พร้อมไฟล์ครบ
2. ติดตั้ง [Inno Setup](https://jrsoftware.org/isdl.php) (ฟรี) ครั้งเดียว
3. รัน `build_installer.bat` — จะ compile ไฟล์ `installer\cookierunautogo.iss` ให้อัตโนมัติ
4. ได้ไฟล์ `installer_output\CookieRunAutoGo_Setup_v1.0.0.exe` — เอาไฟล์นี้ไปใส่ใน
   GitHub Release แทน `.zip` แล้วใช้เป็น `DOWNLOAD_URL` ได้เลย

**ข้อดี:** assets/ ติดไปกับ .exe เสมอ (ติดตั้งให้อัตโนมัติ ไม่มีทางแยกกันได้), มี Shortcut
บน Desktop ให้เอง, มีตัวถอนการติดตั้งใน Windows ให้ด้วย — ดูมืออาชีพและลดคำถามซัพพอร์ต
เรื่อง "หา template ไม่เจอ" ได้มาก

⚠️ ทุกครั้งที่ปล่อยเวอร์ชันใหม่ อย่าลืมแก้ `MyAppVersion` ในไฟล์ `installer\cookierunautogo.iss`
ให้ตรงกับ `CURRENT_VERSION` ใน `license_client.py` ด้วย

## หน้าเว็บจัดการ License (Dashboard)

เปิดเบราว์เซอร์ไปที่:

```
https://your-server-url.example.com/admin/dashboard
```

กรอก `ADMIN_TOKEN` ที่ตั้งไว้ตอน deploy เพื่อเข้าสู่ระบบ (จำ token ไว้ในเบราว์เซอร์แค่ระหว่าง
session เดียว ปิด tab แล้วต้องกรอกใหม่) จากหน้านี้จะ:

- เห็นสรุปจำนวน License ทั้งหมด/ใช้งานได้/ถูกเพิกถอน/แบบเช่า/แบบถาวร/ใกล้หมดอายุ
- สร้าง License Key ใหม่ (เช่า/ถาวร) พร้อมปุ่มคัดลอกคีย์ให้ลูกค้า
- ค้นหา License จากคีย์หรือหมายเหตุ
- กด **เพิกถอน** เพื่อตัดสิทธิ์ผู้ใช้ทันที หรือ **ปลดผูกเครื่อง** เพื่อให้ลูกค้าย้ายไปใช้เครื่องใหม่ได้

> ยังใช้ `admin_cli.py` ควบคู่กันได้ตามปกติ ทั้งสองทางเรียก API เดียวกัน

## สร้าง License Key ครั้งแรก (ผ่าน CLI แทนก็ได้)

```bash
export LICENSE_SERVER_URL="https://your-server-url.example.com"
export ADMIN_TOKEN="your-secret-admin-token"

# สร้างคีย์เช่า 30 วัน 1 คีย์
python admin_cli.py generate --type rental --days 30 --count 1

# สร้างคีย์ถาวร 1 คีย์
python admin_cli.py generate --type permanent --count 1
```

## ระบบแจ้งเตือนอัปเดตเวอร์ชัน

โปรแกรมบอทฝั่ง client จะเช็ค endpoint `GET /version` ทุกครั้งที่เปิดโปรแกรม เพื่อแจ้งเตือน
ผู้ใช้ถ้ามีเวอร์ชันใหม่กว่า ควบคุมค่าทั้งหมดผ่าน **Environment Variable บน Render ได้เลย
ไม่ต้องแก้โค้ด/redeploy**:

| ตัวแปร | ความหมาย |
|---|---|
| `LATEST_VERSION` | เวอร์ชันล่าสุดที่มี เช่น `1.1.0` |
| `DOWNLOAD_URL` | ลิงก์ดาวน์โหลดเวอร์ชันล่าสุด (โปรแกรมจะมีปุ่มเปิดลิงก์นี้ให้ผู้ใช้) |
| `CHANGELOG` | ข้อความสรุปสิ่งที่เปลี่ยนแปลง จะโชว์ให้ผู้ใช้เห็นในหน้าต่างแจ้งเตือน |
| `MIN_REQUIRED_VERSION` | ถ้าตั้งไว้ และเวอร์ชันผู้ใช้ต่ำกว่านี้ จะ **บังคับ**ให้อัปเดตก่อนถึงจะใช้งานต่อได้ (เว้นว่างไว้ = ไม่บังคับ ใช้สำหรับเจอบั๊กร้ายแรงที่ต้องบังคับทุกคนอัปเดตทันที) |

### ตัวอย่างการใช้งาน

ปล่อยเวอร์ชันใหม่ 1.1.0 แบบแจ้งเตือนธรรมดา (ไม่บังคับ):
```
LATEST_VERSION=1.1.0
DOWNLOAD_URL=https://yourdomain.com/downloads/CookieRunAutoGo_v1.1.0.zip
CHANGELOG=แก้บั๊กเรื่องความละเอียดจอ, เพิ่มฟีเจอร์ส่งหัวใจอัตโนมัติ
```

เจอบั๊กร้ายแรงในเวอร์ชัน 1.0.x ต้องการบังคับให้ทุกคนอัปเดตเป็น 1.1.0 ทันที:
```
LATEST_VERSION=1.1.0
MIN_REQUIRED_VERSION=1.1.0
DOWNLOAD_URL=https://yourdomain.com/downloads/CookieRunAutoGo_v1.1.0.zip
CHANGELOG=แก้บั๊กร้ายแรง กรุณาอัปเดตก่อนใช้งานต่อ
```

> อย่าลืมแก้ `CURRENT_VERSION` ในไฟล์ `license_client.py` ของโปรแกรมบอทให้ตรงกับเวอร์ชันจริง
> ทุกครั้งที่ build แจกให้ลูกค้า ไม่งั้นระบบจะเทียบเวอร์ชันผิดพลาด

## ความปลอดภัยที่ควรทำเพิ่ม (สำหรับใช้งานจริง/ขายจริง)

- ตั้ง `ADMIN_TOKEN` ให้ยาวและสุ่มจริงๆ (เช่น `python -c "import secrets; print(secrets.token_hex(32))"`)
- อย่า commit ค่า `ADMIN_TOKEN` หรือ `DATABASE_URL` ลง GitHub — ใส่เป็น Environment
  Variable ของ hosting เท่านั้น (ทั้งสองค่านี้เทียบเท่ารหัสผ่านเข้าระบบทั้งหมด)
- เปิดใช้ HTTPS เสมอ (Render/Railway ทำให้อัตโนมัติ, ถ้า self-host ใช้ Caddy/Let's Encrypt)
- Supabase สำรองข้อมูลให้อัตโนมัติอยู่แล้ว แต่ถ้าต้องการ backup เพิ่มเติมเอง สามารถกด
  Database > Backups ในหน้า Supabase dashboard เพื่อดาวน์โหลด snapshot ได้เช่นกัน
