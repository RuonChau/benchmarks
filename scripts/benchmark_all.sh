#!/bin/bash

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CSV_DIR="$SCRIPT_DIR/../csv_results"
LOG_NODE_DIR="$SCRIPT_DIR/../logs_node"
LOG_RUST_DIR="$SCRIPT_DIR/../logs_rust"
PLOT_FILE__DIR="$SCRIPT_DIR/../plots"

mkdir -p "$CSV_DIR" "$LOG_NODE_DIR" "$LOG_RUST_DIR" "$PLOT_FILE__DIR"

TIMESTAMP=$(date +%Y%m%d_%H%M%S)
FINAL_CSV="$CSV_DIR/benchmark_results_${TIMESTAMP}.csv"
PLOT_FILE="$PLOT_FILE__DIR/benchmark_plot_${TIMESTAMP}.png"

RUST_SCRIPT="$SCRIPT_DIR/benchmark_rust.sh"
NODE_SCRIPT="$SCRIPT_DIR/benchmark_node.sh"

# Kiểm tra nếu gnuplot chưa được cài
if ! command -v gnuplot &> /dev/null; then
    echo "❌ Gnuplot is not installed. Please install it with: sudo apt install gnuplot"
    exit 1
fi

plot_csv() {
    gnuplot -persist <<-EOF
        set datafile separator ","
        set terminal png size 800,600
        set output "$PLOT_FILE"
        set title "Benchmark Durations"
        set xlabel "Step"
        set ylabel "Time (s)"
        set boxwidth 0.5
        set style fill solid
        plot "$FINAL_CSV" using 2:xtic(1) with boxes title "Duration"
EOF
}

if [[ "$1" == "--parallel" ]]; then
    echo "🚀 Running Rust & Node benchmarks in parallel..."
    START=$(date +%s)

    "$RUST_SCRIPT" & PID_RUST=$!
    "$NODE_SCRIPT" & PID_NODE=$!

    wait $PID_RUST
    wait $PID_NODE

    END=$(date +%s)
    TOTAL_DURATION=$((END - START))

    # Tìm 2 file CSV mới nhất từ rust và node
    LATEST_NODE_CSV=$(ls -t "$CSV_DIR"/benchmark_node_*.csv | head -n1)
    LATEST_RUST_CSV=$(ls -t "$CSV_DIR"/benchmark_rust_*.csv | head -n1)

    echo "step,duration(s)" > "$FINAL_CSV"
    tail -n +2 "$LATEST_NODE_CSV" | grep -v "^total" | cut -d',' -f1,2 >> "$FINAL_CSV"
    tail -n +2 "$LATEST_RUST_CSV" | grep -v "^total" | cut -d',' -f1,2 >> "$FINAL_CSV"
    echo "total,$TOTAL_DURATION" >> "$FINAL_CSV"
else
    echo "🚀 Running Rust benchmark..."
    "$RUST_SCRIPT"

    echo "🚀 Running Node benchmark..."
    "$NODE_SCRIPT"

    LATEST_NODE_CSV=$(ls -t "$CSV_DIR"/benchmark_node_*.csv | head -n1)
    LATEST_RUST_CSV=$(ls -t "$CSV_DIR"/benchmark_rust_*.csv | head -n1)

    echo "step,duration(s)" > "$FINAL_CSV"
    tail -n +2 "$LATEST_NODE_CSV" | grep -v "^total" | cut -d',' -f1,2 >> "$FINAL_CSV"
    tail -n +2 "$LATEST_RUST_CSV" | grep -v "^total" | cut -d',' -f1,2 >> "$FINAL_CSV"

    TOTAL_TIME=$(awk -F, 'NR>1 {sum+=$2} END {print sum}' "$FINAL_CSV")
    echo "total,$TOTAL_TIME" >> "$FINAL_CSV"
fi

echo ""
echo "📊 Generating chart with Gnuplot..."
plot_csv

echo "✅ Done! CSV: $FINAL_CSV | Plot: $PLOT_FILE"
