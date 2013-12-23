class Indicatus

  def initialize(variable_indicator, operation)
    @varicator = variable_indicator
    @operation = operation
    @intervention = @operation.intervention
  end

  def value?
    @varicator.value?
  end

  def name
    @varicator.indicator_name
  end

  def datum
    IndicatorDatum.new(@varicator.indicator_name, computed_value)
  end

  def actor
    if cast = @intervention.casts.find_by(reference_name: @varicator.stakeholder.name)
      return cast.actor
    else
      return nil
    end
  end

  def computed_value(options = {})
    if @varicator.value?
      expr = @varicator.value.strip
      # Computed value
      if expr =~ /\A(\w+)?[[:space:]]*\:[[:space:]]*\w+\z/
        computation, var = expr.split(/[[:space:]]*\:[[:space:]]*/)[0..1]
        computation = (computation.blank? ? :same_as : computation.underscore.to_sym)
        source_var = @varicator.procedure.variables[var]
        source_cast = @intervention.casts.find_by(reference_name: source_var.name.to_s)
        source_actor = source_cast.actor
        cast  = @intervention.casts.find_by(reference_name: @varicator.stakeholder.name)
        actor = cast.actor
        if computation == :superficial_count
          if source_actor.indicators_list.include?(:shape)
            if actor.indicators_list.include?(:net_surface_area)
              whole      = source_actor.net_surface_area!(@operation.started_at).to_f(:square_meter)
              individual = actor.net_surface_area!(@operation.started_at, gathering: false).to_f(:square_meter)
              return (whole / individual)
            else
              raise StandardError, "Cannot compute superficial count if with a product without net_surface_area indicator."
            end
          else
            raise StandardError, "Cannot compute superficial count with a source product without shape indicator #{source_actor.nature.inspect}."
          end
        else # if computation == :same_as
          if source_actor.indicators.include?(@varicator.indicator)
            return source_actor.get!(@varicator.indicator, @operation.started_at)
          else
            raise StandardError, "Cannot get #{@varicator.indicator_name} from a source product without this indicator #{source_actor.nature.inspect}."
          end
        end
      else
        # Direct value
        return expr
      end
    else
      raise NotImplementedError
    end
  end

end
