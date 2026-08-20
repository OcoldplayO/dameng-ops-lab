#!/usr/bin/env python3
# -*- coding: utf-8 -*-
import smtplib
from email.mime.text import MIMEText
from email.header import Header
import sys

# 优先从外部参数获取，没有则使用你原版的默认配置
SENDER_QQ = sys.argv[3] if len(sys.argv) > 3 else "1770126791@qq.com"
AUTH_CODE = sys.argv[4] if len(sys.argv) > 4 else "xvllzyxaocbyfach"
RECEIVER_EMAIL = sys.argv[5] if len(sys.argv) > 5 else "1770126791@qq.com"

subject = sys.argv[1] if len(sys.argv) > 1 else "系统默认报警"
raw_content = sys.argv[2] if len(sys.argv) > 2 else "测试内容"
html_content = raw_content.replace('\\n', '<br>').replace('\n', '<br>')

def send_email(sub, msg):
    message = MIMEText(f"<div style='font-family: Arial; font-size: 15px; line-height: 1.8; color: #333;'>{msg}</div>", 'html', 'utf-8')
    # 严格保持原版：直接赋值字符串，绝不加 Header 编码
    message['From'] = SENDER_QQ
    message['To'] = RECEIVER_EMAIL
    message['Subject'] = Header(sub, 'utf-8')

    try:
        smtp_obj = smtplib.SMTP_SSL('smtp.qq.com', 465, timeout=10)
        smtp_obj.login(SENDER_QQ, AUTH_CODE)
        smtp_obj.sendmail(SENDER_QQ, [RECEIVER_EMAIL], message.as_string())
        smtp_obj.quit()
        print("✅ 邮件发送成功！")
    except Exception as e:
        print(f"❌ 邮件发送失败: {e}", file=sys.stderr)

if __name__ == '__main__':
    send_email(subject, html_content)
