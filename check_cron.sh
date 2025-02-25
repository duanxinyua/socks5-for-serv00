#!/bin/bash

USER=$(whoami)
WORKDIR="/home/${USER}/.nezha-agent"
WORKDIR_dashboard="/home/${USER}/.nezha-dashboard"
WORKDIR_alist="/home/${USER}/domains/alist.hetao.pw"
WORKDIR_xui="/home/${USER}"
FILE_PATH="/home/${USER}/.s5"
CRON_S5="nohup ${FILE_PATH}/s5 -c ${FILE_PATH}/config.json >/dev/null 2>&1 &"
CRON_NEZHA="nohup ${WORKDIR}/start.sh >/dev/null 2>&1 &"
PM2_PATH="/home/${USER}/.npm-global/lib/node_modules/pm2/bin/pm2"
CRON_JOB="0 * * * * $PM2_PATH resurrect >> /home/$(whoami)/pm2_resurrect.log 2>&1"
REBOOT_COMMAND="@reboot pkill -kill -u $(whoami) && $PM2_PATH resurrect >> /home/$(whoami)/pm2_resurrect.log 2>&1"

echo "检查并添加 crontab 任务"

# 检查和添加任务函数
add_cron_task() {
  local task="$1"
  local retry=0
  local max_retries=3

  until [ $retry -ge $max_retries ]; do
    # 检查任务是否存在
    if (crontab -l 2>/dev/null | grep -Fq "$task"); then
      echo "任务 '$task' 已成功添加。"
      return 0
    fi

    # 任务不存在，尝试添加
    (crontab -l 2>/dev/null; echo "$task") | crontab -
    ((retry++))
    echo "尝试添加任务 '$task'（第 $retry 次）..."

    sleep 1 # 等待1秒后重试
  done

  echo "任务 '$task' 添加失败，重试 $max_retries 次仍未成功！"
  return 1
}

if [ "$(command -v pm2)" == "/home/${USER}/.npm-global/bin/pm2" ]; then
  echo "已安装 pm2，并返回正确路径，启用 pm2 保活任务"
  add_cron_task "$REBOOT_COMMAND"
  add_cron_task "$CRON_JOB"
else
  if [ -e "${WORKDIR}/start.sh" ] && [ -e "${FILE_PATH}/config.json" ]; then
    echo "添加 nezha & socks5 的 crontab 重启任务"
    add_cron_task "@reboot pkill -kill -u $(whoami) && ${CRON_S5} && ${CRON_NEZHA}"
    add_cron_task "0 * * * * pgrep -x \"nezha-agent\" > /dev/null || ${CRON_NEZHA}"
    add_cron_task "0 * * * * pgrep -x \"s5\" > /dev/null || ${CRON_S5}"
  elif [ -e "${WORKDIR}/start.sh" ]; then
    echo "添加 nezha 的 crontab 重启任务"
    add_cron_task "@reboot pkill -kill -u $(whoami) && ${CRON_NEZHA}"
    add_cron_task "0 * * * * pgrep -x \"nezha-agent\" > /dev/null || ${CRON_NEZHA}"
  elif [ -e "${FILE_PATH}/config.json" ]; then
    echo "添加 socks5 的 crontab 重启任务和定时任务"
    add_cron_task "@reboot pkill -kill -u $(whoami) && ${CRON_S5}"
    add_cron_task "5 * * * * pgrep -x \"s5\" > /dev/null || ${CRON_S5}"
  fi
fi

# 独立检查 nezha-dashboard
if [ -e "${WORKDIR_dashboard}/start.sh" ]; then
  echo "检测到哪吒面板，正在重启。"
  nohup ${WORKDIR_dashboard}/start.sh >/dev/null 2>&1 &
  echo "正在启动 nezha-dashboard，请耐心等待..."
  sleep 3
  if pgrep -f "dashboard" > /dev/null; then
    echo "nezha-dashboard 已启动。"
  else
    echo "nezha-dashboard 启动失败，请检查端口开放情况，并保证参数填写正确，再重新安装！"
  fi
fi


# 独立检查 alist
if [ -d "${WORKDIR_alist}" ] && ! pgrep -f "screen.*alist" > /dev/null; then
  echo "检测到 alist 未启动，正在重启..."
  cd ${WORKDIR_alist} && screen -dmS alist ./alist server
  echo "alist 正在启动，请耐心等待..."
  sleep 3

  # 检查 alist 是否成功启动
  if pgrep -f "screen.*alist" > /dev/null; then
    echo "alist 已启动，并且在 screen 会话中运行。"
  else
    echo "alist 启动失败，请检查端口开放情况，并确保参数填写正确，再重新安装！"
  fi
fi



# 独立检查 X-UI
PID=$(pgrep -f "x-ui")

# 检查工作目录和 x-ui.sh 是否存在
if [ -e "${WORKDIR_xui}/x-ui.sh" ]; then
  echo "检测到存在 X-UI，正在停止..."

  # 停止 X-UI
  if [ -n "$PID" ]; then
    kill "$PID"
    sleep 3
    if pgrep -f "x-ui" > /dev/null; then
      echo "X-UI 停止失败，尝试再次停止..."
      kill "$PID"
      sleep 3
    else
      echo "X-UI 已成功停止。"
    fi
  else
    echo "未检测到运行中的 X-UI 进程。"
  fi

  # 启动 X-UI
  echo "正在启动 X-UI..."
  nohup "${WORKDIR_xui}/x-ui.sh" restart >/dev/null 2>&1 &
  nohup "${WORKDIR_xui}/x-ui.sh" enable >/dev/null 2>&1 &
  sleep 3
  if pgrep -f "x-ui" > /dev/null; then
    echo "X-UI 已成功启动。"
  else
    echo "X-UI 启动失败，请检查定时脚本！"
  fi
else
  echo "没有安装X-UI，跳过此项任务。"
fi
