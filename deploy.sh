#!/bin/bash

set -e

DOMAIN=tokyo.daoguilai.com

# 1. 安装依赖
sudo apt update
sudo apt install -y python3-pip python3-venv nginx

# 2. 创建项目文件夹
mkdir -p ~/webtest/templates
cd ~/webtest

# 3. 写入Flask文件
cat > app.py <<EOF
from flask import Flask, render_template

app = Flask(__name__)

@app.route("/")
def home():
    return render_template("index.html")

if __name__ == "__main__":
    app.run()
EOF

cat > requirements.txt <<EOF
Flask==3.0.3
gunicorn==21.2.0
EOF

cat > templates/index.html <<EOF
<!DOCTYPE html>
<html>
<head>
    <title>Flask Nginx 测试页</title>
</head>
<body>
    <h1>部署成功！</h1>
    <p>欢迎来到 Flask + Nginx 测试页面</p>
</body>
</html>
EOF

# 4. 配置虚拟环境
python3 -m venv venv
source venv/bin/activate
pip install -r requirements.txt

# 5. 配置 Gunicorn systemd 服务
sudo tee /etc/systemd/system/webtest.service > /dev/null <<EOF
[Unit]
Description=Gunicorn instance to serve webtest
After=network.target

[Service]
User=$USER
Group=www-data
WorkingDirectory=/home/$USER/webtest
Environment="PATH=/home/$USER/webtest/venv/bin"
ExecStart=/home/$USER/webtest/venv/bin/gunicorn -w 2 -b 127.0.0.1:8000 app:app

[Install]
WantedBy=multi-user.target
EOF

sudo systemctl daemon-reload
sudo systemctl enable webtest
sudo systemctl restart webtest

# 6. 配置Nginx（含域名）
sudo tee /etc/nginx/sites-available/webtest > /dev/null <<EOF
server {
    listen 80;
    server_name $DOMAIN;

    location / {
        proxy_pass http://127.0.0.1:8000;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
    }
}
EOF

sudo ln -sf /etc/nginx/sites-available/webtest /etc/nginx/sites-enabled/webtest
sudo rm -f /etc/nginx/sites-enabled/default
sudo nginx -t && sudo systemctl reload nginx

# 7. 可选：自动申请并配置 HTTPS（Let’s Encrypt）
echo "是否自动配置 HTTPS？(y/n)"
read use_ssl
if [[ "$use_ssl" == "y" || "$use_ssl" == "Y" ]]; then
    sudo apt install -y certbot python3-certbot-nginx
    sudo certbot --nginx -d $DOMAIN --redirect --agree-tos --register-unsafely-without-email
fi

echo "=============================="
echo " 部署完成！访问 http://$DOMAIN 即可看到测试页"
if [[ "$use_ssl" == "y" || "$use_ssl" == "Y" ]]; then
  echo " 已自动申请 HTTPS，访问 https://$DOMAIN"
fi
echo "=============================="
