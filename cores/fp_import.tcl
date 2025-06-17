proc addFpCores {coredir} {
	set ip_files [glob -nocomplain $coredir/*/*.xci]
	add_files $ip_files
}

