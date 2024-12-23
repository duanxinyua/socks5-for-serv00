#!/bin/bash

USER=$(whoami)
WORKDIR="/home/${USER}/.nezha-agent"
WORKDIR_dashboard="/home/${USER}/.nezha-dashboard"
FILE_PATH="/home/${USER}/.s5"
CRON_S5="nohup ${FILE_PATH}/s5 -c ${FILE_PATH}/config.json >/dev/null 2>&1 &"
CRON_NEZHA="nohup ${WORKDIR}/start.sh >/dev/null 2>&1 &"
PM2_PATH="/home/${USER}/.npm-global/lib/node_modules/pm2/bin/pm2"
CRON_JOB="*/12 * * * * $PM2_PATH resurrect >> /home/$(whoami)/pm2_resurrect.log 2>&1"
REBOOT_COMMAND="@reboot pkill -kill -u $(whoami) && $PM2_PATH resurrect >> /home/$(whoami)/pm2_resurrect.log 2>&1"

echo "检查并添加 crontab 任务"

if [ "$(command -v pm2)" == "/home/${USER}/.npm-global/bin/pm2" ]; then
  echo "已安装 pm2，并返回正确路径，启用 pm2 保活任务"
  (crontab -l | grep -F "$REBOOT_COMMAND") || (crontab -l; echo "$REBOOT_COMMAND") | crontab -
  (crontab -l | grep -F "$CRON_JOB") || (crontab -l; echo "$CRON_JOB") | crontab -
else
  if [ -e "${WORKDIR}/start.sh" ] && [ -e "${FILE_PATH}/config.json" ]; then
    echo "添加 nezha & socks5 的 crontab 重启任务"
    (crontab -l | grep -F "@reboot pkill -kill -u $(whoami) && ${CRON_S5} && ${CRON_NEZHA}") || (crontab -l; echo "@reboot pkill -kill -u $(whoami) && ${CRON_S5} && ${CRON_NEZHA}") | crontab -
    (crontab -l | grep -F "* * pgrep -x \"nezha-agent\" > /dev/null || ${CRON_NEZHA}") || (crontab -l; echo "*/12 * * * * pgrep -x \"nezha-agent\" > /dev/null || ${CRON_NEZHA}") | crontab -
    (crontab -l | grep -F "* * pgrep -x \"s5\" > /dev/null || ${CRON_S5}") || (crontab -l; echo "*/12 * * * * pgrep -x \"s5\" > /dev/null || ${CRON_S5}") | crontab -
  elif [ -e "${WORKDIR}/start.sh" ]; then
    echo "添加 nezha 的 crontab 重启任务"
    (crontab -l | grep -F "@reboot pkill -kill -u $(whoami) && ${CRON_NEZHA}") || (crontab -l; echo "@reboot pkill -kill -u $(whoami) && ${CRON_NEZHA}") | crontab -
    (crontab -l | grep -F "* * pgrep -x \"nezha-agent\" > /dev/null || ${CRON_NEZHA}") || (crontab -l; echo "*/12 * * * * pgrep -x \"nezha-agent\" > /dev/null || ${CRON_NEZHA}") | crontab -
  elif [ -e "${FILE_PATH}/config.json" ]; then
    # echo "添加 socks5 的 crontab 重启任务"
    # (crontab -l | grep -F "@reboot pkill -kill -u $(whoami) && ${CRON_S5}") || (crontab -l; echo "@reboot pkill -kill -u $(whoami) && ${CRON_S5}") | crontab -
    # (crontab -l | grep -F "* * pgrep -x \"s5\" > /dev/null || ${CRON_S5}") || (crontab -l; echo "5 * * * * pgrep -x \"s5\" > /dev/null || ${CRON_S5}") | crontab -
    echo "添加 socks5 的 crontab 重启任务和定时任务"

    # 添加重启任务
    CRON_REBOOT="@reboot pkill -kill -u $(whoami) && ${CRON_S5}"
    (crontab -l 2>/dev/null | grep -F "${CRON_REBOOT}") || (crontab -l 2>/dev/null; echo "${CRON_REBOOT}") | crontab -
    
    # 添加定时任务
    CRON_CHECK="5 * * * * pgrep -x \"s5\" > /dev/null || ${CRON_S5}"
    (crontab -l 2>/dev/null | grep -F "${CRON_CHECK}") || (crontab -l 2>/dev/null; echo "${CRON_CHECK}") | crontab -

  #添加面板的自动重启
  elif [ -e "${WORKDIR_dashboard}/start.sh" ]; then
      nohup ${WORKDIR_dashboard}/start.sh >/dev/null 2>&1 &
      echo "正在启动nezha-dashboard，请耐心等待...\n"
      sleep 3
      if pgrep -f "dashboard" > /dev/null; then
          echo "nezha-dashboard 已启动。"
      else
          echo "nezha-dashboard 启动失败，请检查端口开放情况，并保证参数填写正确，再重新安装！"
      fi
  fi
fi
