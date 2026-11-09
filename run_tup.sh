#!/bin/bash
set -uo pipefail

PROJ_DIR="/opt/pentaho-etl/projetos/tup"
LOG_DIR="$PROJ_DIR/logs"
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
LOG_FILE="$LOG_DIR/tup_${TIMESTAMP}.log"
KETTLE_PROPS="/home/ec2-user/.kettle/kettle.properties"

mkdir -p "$LOG_DIR"

echo "=== Início da execução: $(date '+%Y-%m-%d %H:%M:%S') ===" | tee -a "$LOG_FILE"

docker run --rm \
  --network host \
  -v "$PROJ_DIR:/opt/pentaho/projetos/tup" \
  -v "$KETTLE_PROPS:/home/pentaho/.kettle/kettle.properties:ro" \
  pentaho-etl:9.4 \
  -file=/opt/pentaho/projetos/tup/tup.kjb \
  -level=Basic >> "$LOG_FILE" 2>&1

EXIT_CODE=$?

if [ $EXIT_CODE -eq 0 ]; then
  echo "=== SUCESSO: $(date '+%Y-%m-%d %H:%M:%S') (exit code $EXIT_CODE) ===" | tee -a "$LOG_FILE"
else
  echo "=== FALHA: $(date '+%Y-%m-%d %H:%M:%S') (exit code $EXIT_CODE) ===" | tee -a "$LOG_FILE"
fi

find "$LOG_DIR" -name "tup_*.log" -mtime +30 -delete

exit $EXIT_CODE
