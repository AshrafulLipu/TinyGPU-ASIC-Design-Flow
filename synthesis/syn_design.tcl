# === Set the design name [From top :module] ===#
set DESIGN gpu

# === Set the search path === #
set_db init_lib_search_path {/home/user_75/Project/Tiny_GPU/input/lib}
set_db init_hdl_search_path {/home/user_75/Project/Tiny_GPU/input/rtl}

# === Read the files ===
read_libs slow_vdd1v0_basicCells.lib
set_db lef_library {/home/user_75/Project/Tiny_GPU/input/lef/gsclib045_tech.lef /home/user_75/Project/Tiny_GPU/input/lef/gsclib045_macro.lef}
read_hdl gpu.v alu.v controller.v core.v dcr.v decoder.v dispatch.v fetcher.v lsu.v pc.v registers.v scheduler.v

# === Elaborate the design ===
elaborate $DESIGN

# === Apply constraints ===
read_sdc {/home/user_75/Project/Tiny_GPU/input/constraints/constraints_top.sdc}

# === Lint report ===
report_timing -lint > /home/user_75/Project/Tiny_GPU/report/report.pdf

# === Set Synthesis Effort ===
set_db syn_generic_effort high
set_db syn_map_effort high
set_db syn_opt_effort high

# === Run Synthesis Steps ===
syn_generic
syn_map
syn_opt

# === Analyze Desin ===
report_timing > /home/user_75/Project/Tiny_GPU/report/timing.rpt
report_power  > /home/user_75/Project/Tiny_GPU/report/power.rpt
report_area   > /home/user_75/Project/Tiny_GPU/report/area.rpt
report_qor    > /home/user_75/Project/Tiny_GPU/report/qor.rpt

# === Export Design ===
write_hdl     > /home/user_75/Project/Tiny_GPU/output/gpu_netlist.v
write_sdc     > /home/user_75/Project/Tiny_GPU/output/gpu_sdc.sdc
write_script  > /home/user_75/Project/Tiny_GPU/output/gpu_constraints.g

# ===Save Database [Saved in only genus] ===
write_db -common /home/user_75/Project/Tiny_GPU/output/gpu_design.db

# === GENUS log collection ===
foreach f [glob -nocomplain *.log *.cmd *.txt] {
    file rename -force $f ../SYN/logs_genus/
}

