#!/usr/bin/env bash
# 创建 SSE 跨实例广播所需 Kafka 主题。
#
# 依赖 PATH 中可执行的 kafka-topics.sh（Kafka 发行版 bin 目录）。
# 可用环境变量覆盖：
#   KAFKA_BROKERS      默认 127.0.0.1:9092
#   KAFKA_TOPIC        默认 admin.events
#   KAFKA_TOPICS_BIN   默认 kafka-topics.sh
#   KAFKA_PARTITIONS   默认 3

set -euo pipefail

BROKERS="${KAFKA_BROKERS:-127.0.0.1:9092}"
TOPIC="${KAFKA_TOPIC:-admin.events}"
TOPICS_BIN="${KAFKA_TOPICS_BIN:-kafka-topics.sh}"
PARTITIONS="${KAFKA_PARTITIONS:-3}"
RETENTION_MS=$((24 * 60 * 60 * 1000)) # 保留 1 天

"$TOPICS_BIN" \
  --bootstrap-server "$BROKERS" \
  --create \
  --if-not-exists \
  --topic "$TOPIC" \
  --partitions "$PARTITIONS" \
  --replication-factor 1 \
  --config "retention.ms=${RETENTION_MS}"

echo "主题 ${TOPIC} 已就绪（brokers=${BROKERS}, partitions=${PARTITIONS}, retention=1d）"
