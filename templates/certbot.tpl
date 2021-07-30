---
- name: Ensure certbot is installed
  apt:
    name={{ item }}
    state=present
  with_items:
    - certbot

- name:
  shell: certbot certonly --standalone --agree-tos -m ${email} -d {{ inventory_hostname }}.${domain} -n
