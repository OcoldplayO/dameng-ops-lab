#!/usr/bin/env python3
# -*- coding: utf-8 -*-
import smtplib
from email.mime.text import MIMEText
from email.header import Header
import sys

SENDER_QQ = sys.argv[3] if len(sys.argv) > 3 else "1770126791@qq.com"
AUTH_CODE = sys.argv[4] if len(sys.argv) > 4 else "xvllzyxaocbyfach"
RECEIVER_EMAIL = sys.argv[5] if len(sys.argv) > 5 else "1770126791@qq.com"

subject = sys.argv[1] if len(sys.argv) > 1 else "系统默认报警"
raw_content = sys.argv[2] if len(sys.argv) > 2 else "测试内容"

# 关键修复：如果已经是包含 <table> 或 <div> 的 HTML 代码，不再进行盲目换行替换，保证 HTML 语法 100% 合规
if "<table" not in raw_content and "<div" not in raw_content:
    html_content = raw_content.replace('\\n', '<br>').replace('\n', '<br>')
else:
    html_content = raw_content

def send_email(sub, msg):
    message = MIMEText(msg, 'html', 'utf-8')
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
