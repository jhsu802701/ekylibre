Exchanges.add_importer(:agro_systemes_soil_analyses) do |file, w|
  analyser_attributes = YAML.load_file(File.join(File.dirname(__FILE__), "entity.yml"))

  unless analyser = LegalEntity.find_by(siren: analyser_attributes[:siren])
    analyser = LegalEntity.create!(analyser_attributes)
  end

  begin
    rows = CSV.read(file, encoding: "CP1252", col_sep: "\t", headers: true)
  rescue
    raise NotWellFormedFileError
  end
  w.count = rows.size

  rows.each do |row|
    r = OpenStruct.new(:code_distri => (row[0].blank? ? nil : row[0].to_s),
                       :reference_number => row[6].to_s,
                       :at => (row[7].blank? ? nil : Date.civil(*row[7].to_s.split(/\//).reverse.map(&:to_i))),
                       :landparcel_work_number => row[8].blank? ? nil : landparcels_transcode[row[8]],
                       :analyse_soil_nature => row[10].blank? ? nil : soil_natures_transcode[row[10]],
                       :organic_matter_concentration => row[38].blank? ? nil : (row[38].to_d).in_percent,
                       :potential_hydrogen => row[41].blank? ? nil : row[41].to_d,
                       :cation_exchange_capacity => row[47].blank? ? nil : (row[47].to_d).in_milliequivalent_per_hundred_gram,
                       :p2o5_olsen_ppm_value => row[49].blank? ? nil : (row[49].to_d).in_parts_per_million,
                       :p_ppm_value => row[49].blank? ? nil : ((row[49].to_d)*0.436).in_parts_per_million,
                       :k2o_ppm_value => row[55].blank? ? nil : (row[55].to_d).in_parts_per_million,
                       :k_ppm_value => row[55].blank? ? nil : ((row[55].to_d)*0.83).in_parts_per_million,
                       :mg_ppm_value => row[61].blank? ? nil : (row[61].to_d).in_parts_per_million,
                       :b_ppm_value => row[82].blank? ? nil : (row[82].to_d).in_parts_per_million,
                       :zn_ppm_value => row[85].blank? ? nil : (row[85].to_d).in_parts_per_million,
                       :mn_ppm_value => row[88].blank? ? nil : (row[88].to_d).in_parts_per_million,
                       :cu_ppm_value => row[91].blank? ? nil : (row[91].to_d).in_parts_per_million,
                       :fe_ppm_value => row[94].blank? ? nil : (row[94].to_d).in_parts_per_million,
                       :sampled_at => (row[179].blank? ? nil : Date.civil(*row[179].to_s.split(/\//).reverse.map(&:to_i)))
                       )

    unless analysis = Analysis.where(reference_number: r.reference_number, analyser: analyser).first
      analysis = Analysis.create!(reference_number: r.reference_number, nature: "soil_analysis",
                                  analyser: analyser, sampled_at: r.sampled_at, analysed_at: r.at)

      analysis.read!(:soil_nature, r.analyse_soil_nature) if r.analyse_soil_nature
      analysis.read!(:organic_matter_concentration, r.organic_matter_concentration) if r.organic_matter_concentration
      analysis.read!(:potential_hydrogen, r.potential_hydrogen) if r.potential_hydrogen
      analysis.read!(:cation_exchange_capacity, r.cation_exchange_capacity) if r.cation_exchange_capacity
      analysis.read!(:phosphate_concentration, r.p2o5_olsen_ppm_value) if r.p2o5_olsen_ppm_value
      analysis.read!(:potash_concentration, r.k2o_ppm_value) if r.k2o_ppm_value
      analysis.read!(:magnesium_concentration, r.mg_ppm_value) if r.mg_ppm_value
      analysis.read!(:boron_concentration, r.b_ppm_value) if r.b_ppm_value
      analysis.read!(:zinc_concentration, r.zn_ppm_value) if r.zn_ppm_value
      analysis.read!(:manganese_concentration, r.mn_ppm_value) if r.mn_ppm_value
      analysis.read!(:copper_concentration, r.cu_ppm_value) if r.cu_ppm_value
      analysis.read!(:iron_concentration, r.fe_ppm_value) if r.fe_ppm_value
    end
    # if an lan_parcel exist , link to analysis
    if land_parcel = LandParcel.find_by_work_number(r.landparcel_work_number)
      analysis.product = land_parcel
      analysis.save!
      land_parcel.read!(:soil_nature, r.analyse_soil_nature, at: r.sampled_at) if r.analyse_soil_nature
      land_parcel.read!(:phosphorus_concentration, r.p_ppm_value, at: r.sampled_at) if r.p_ppm_value
      land_parcel.read!(:potassium_concentration, r.k_ppm_value, at: r.sampled_at) if r.k_ppm_value
    end

    w.check_point
  end

end
