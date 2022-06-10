class RbTeam < Group
  unloadable
  def position
    0
  end
  def status
    nil
  end
  def subject
    lastname
  end
end



class RbGenericboard < ActiveRecord::Base
  include Redmine::SafeAttributes
  #attr_accessible :col_type, :element_type, :name, :prefilter, :colfilter, :rowfilter, :row_type,
  #  :include_none_in_rows, :include_none_in_cols, :include_closed_elements, :immutable_positions,
  #  :hide_empty_rows
  serialize :prefilter, Array
  serialize :rowfilter, Array
  serialize :colfilter, Array
  serialize :boardoptions, Hash

  attr_accessor :filteroptions

  public

  safe_attributes 'name',
    'element_type',
    'row_type',
    'col_type',
    'prefilter',
    'rowfilter',
    'colfilter',
    'include_none_in_rows',
    'include_none_in_cols',
    'include_closed_elements',
    'immutable_positions',
    'hide_empty_rows'

  private

  def open_shared_versions(project)
    #similar to project.open_shared_sprints but we not become(RbSprint) and return scopable query
    if Backlogs.setting[:sharing_enabled]
      order = 'ASC'
      project.shared_versions.visible.where(:status => ['open', 'locked']).order("sprint_start_date #{order}, effective_date #{order}")
    else #no backlog sharing
      RbSprint.open_sprints(project)
    end
  end

  def open_releases_by_date(project)
    #similar to project.open_releases_by_date but we want to order ascending
    #order = 'ASC'
    (Backlogs.setting[:sharing_enabled] ? project.shared_releases : project.releases).
      visible.open.
      reorder("#{RbRelease.table_name}.release_end_date ASC, #{RbRelease.table_name}.release_start_date ASC")
  end


  def __sprints_condition(project, filter, filteroptions={})
    options = {}
    options[:conditions] ||= []
    pf = filter_objects(project, filter, filteroptions)
    #FIXME
    r = pf['__current_or_no_release'] || pf['__current_release']
    if !r.is_a?(Integer) && r
      condition = ["#{RbSprint.table_name}.sprint_start_date >= ? and #{RbSprint.table_name}.effective_date <= ? ", r.release_start_date, r.release_end_date]
      Backlogs::ActiveRecord.add_condition(options, condition) if condition
    end
    r = pf['__current_or_no_sprint'] || pf['__current_sprint']
    if !r.is_a?(Integer) &&  r
      condition = ["#{RbSprint.table_name}.id = ?", r.id]
      Backlogs::ActiveRecord.add_condition(options, condition) if condition
    end
    options
  end

  def __release_condition(project, filter, filteroptions={})
    options = {}
    options[:conditions] ||= []
    #FIXME
    pf = filter_object_ids(project, filter, filteroptions)
    r = pf['__current_release'] || pf['__current_or_no_release']
    if !r.blank? && r > 0
      condition = ["#{RbRelease.table_name}.id = ? ", r]
      Backlogs::ActiveRecord.add_condition(options, condition) if condition
    end
    options
  end

  def __team_condition(project, filter, filteroptions={})
    options = {}
    options[:conditions] ||= []
    pf = filter_object_ids(project, filter, filteroptions)
    #FIXME
    r = pf['__my_team']
    if !r.blank? && r > 0
      condition = ["#{Group.table_name}.id = ? ", r]
      Backlogs::ActiveRecord.add_condition(options, condition) if condition
    end
    options
  end

  def __element_condition(project, filter, filteroptions={}) #FIXME codesmell
    options = {}
    options[:conditions] ||= []
    pf = filter_object_ids(project, filter, filteroptions)

    if pf.include? '__current_release'
      id = pf['__current_release']
      if id < 0 # None
        condition = ["#{RbGeneric.table_name}.release_id is null "]
      elsif id > 0
        condition = ["#{RbGeneric.table_name}.release_id = ? ", id]
      else
        condition = nil
      end
      Backlogs::ActiveRecord.add_condition(options, condition) if condition
    end

    if pf.include? '__current_or_no_release'
      id = pf['__current_release']
      if id < 0 # None
        condition = ["#{RbGeneric.table_name}.release_id is null "]
      elsif id > 0
        condition = ["(#{RbGeneric.table_name}.release_id is null or #{RbGeneric.table_name}.release_id = ?) ", id]
      else
        condition = nil
      end
      Backlogs::ActiveRecord.add_condition(options, condition) if condition
    end

    if pf.include? '__current_sprint'
      id = pf['__current_sprint']
      if id < 0 # None
        condition = ["#{RbGeneric.table_name}.fixed_version_id is null "]
      elsif id > 0
        condition = ["#{RbGeneric.table_name}.fixed_version_id = ? ", id]
      else
        condition = nil
      end
      Backlogs::ActiveRecord.add_condition(options, condition) if condition
    end

    if pf.include? '__current_or_no_sprint'
      id = pf['__current_sprint']
      if id < 0 # None
        condition = ["#{RbGeneric.table_name}.fixed_version_id is null "]
      elsif id > 0
        condition = ["(#{RbGeneric.table_name}.fixed_version_id is null or #{RbGeneric.table_name}.fixed_version_id = ?) ", id]
      else
        condition = nil
      end
      Backlogs::ActiveRecord.add_condition(options, condition) if condition
    end

    if pf.include? '__my_team'
      id = pf['__my_team']
      if id < 0 # None
        condition = ["#{RbGeneric.table_name}.rbteam_id is null "]
      elsif id > 0
        condition = ["(#{RbGeneric.table_name}.rbteam_id = ?) ", id]
      else
        condition = nil
      end
      Backlogs::ActiveRecord.add_condition(options, condition) if condition
    end

    if pf.include? '__parent'
      id = pf['__parent']
      if id < 0 # None
        condition = ["#{RbGeneric.table_name}.parent_id is null "]
      elsif id > 0
        condition = ["(#{RbGeneric.table_name}.parent_id = ?) ", id]
      else
        condition = nil
      end
      Backlogs::ActiveRecord.add_condition(options, condition) if condition
    end

    unless include_closed_elements?
      Backlogs::ActiveRecord.add_condition(options, ["is_closed = ?", false])
    end

    options
  end


  def resolve_scope(object_type, project, filter, options={})
    case object_type
    when '__sprint'
      conditions = __sprints_condition(project, filter, options)
      open_shared_versions(project).where(conditions[:conditions]).collect{|v| v.becomes(RbSprint)}

    when '__release'
      conditions = __release_condition(project, filter, options)
      open_releases_by_date(project).where(conditions[:conditions])

    when '__team'
      conditions = __team_condition(project, filter, options)
      Group.order(:lastname).where(conditions[:conditions]).collect{|g| g.becomes(RbTeam) }

    when '__state'
      tracker = Tracker.find(element_type) #FIXME multiple trackers, no tracker
      tracker.issue_statuses

    else #assume an id of tracker, see our options in helper
      tracker_id = object_type
      conditions = __element_condition(project, filter, options)
      return RbGeneric.visible.
        where(conditions[:conditions]).
        generic_backlog_scope({
            :project => project,
            :trackers => resolve_trackers(tracker_id)
        }).
        order("#{RbGeneric.table_name}.position")
    end
  end

  def resolve_trackers(object_type)
    if object_type.start_with?('__')
      return nil
    end
    RbGeneric.all_trackers(Tracker.find(object_type).id)
  end

  def resolve_parent_attribute(object_type)
    case object_type
    when '__sprint'
      :sprint
    when '__release'
      :release
    when '__team'
      :rbteam
    when '__state'
      :status
    else
      :parent
    end
  end

  def find_filter_object_id(project, f, filteroptions)
    obj = find_filter_object(project, f, filteroptions)
    if obj.is_a? Integer
      return obj
    else
      return obj.id
    end
  end

  def find_filter_object(project, f, filteroptions)
    return nil if project.nil?
    case f
    when '__current_release', '__current_or_no_release'
      if filteroptions.include? '__release'
        if filteroptions['__release'].to_i > 0
          RbRelease.where(:id => filteroptions['__release']).take || project.active_release || nil
        else
          filteroptions['__release'].to_i
        end
      else
        project.active_release || 0
      end

    when '__current_sprint', '__current_or_no_sprint'
      if filteroptions.include? '__sprint'
        if filteroptions['__sprint'].to_i > 0
          RbSprint.where(:id => filteroptions['__sprint']).take || project.active_sprint || nil
        else
          filteroptions['__sprint'].to_i
        end
      else
        project.active_sprint || 0
      end

    when '__my_team'
      if filteroptions.include? '__team'
        if filteroptions['__team'].to_i > 0
          Group.where(:id => filteroptions['__team']).take || User.current.groups.order(:lastname).first || nil
        else
          filteroptions['__team'].to_i
        end
      else
        User.current.groups.order(:lastname).first || 0
      end

    when '__parent'
      if filteroptions.include? '__parent'
        if filteroptions['__parent'].to_i > 0
          RbGeneric.where(:id => filteroptions['__parent']).take || nil
        else
          filteroptions['__parent'].to_i
        end
      else
        RbGeneric.epics({:project=>project}).order(:subject).first || 0
      end
    else
      0
    end
  end

  def find_filter_alternative_options(project, f)
    return nil if project.nil?
    case f
    when '__current_sprint', '__current_or_no_sprint'
      open_shared_versions(project).to_a
    when '__current_release', '__current_or_no_release'
      open_releases_by_date(project).to_a
    when '__my_team'
      #User.current.groups.order(:lastname).to_a
      Group.order(:lastname).to_a
    when '__parent'
      RbGeneric.epics({:project => project}).order(:position).to_a
    else
      nil
    end
  end

  def find_filter_option_key(f)
    case f
    when '__current_sprint', '__current_or_no_sprint'
      '__sprint'
    when '__current_release', '__current_or_no_release'
      '__release'
    when '__my_team'
      '__team'
    when '__parent'
      '__parent'
    else
      nil
    end
  end

  public

  def to_s
    name
  end

  def resolve_class(object_type)
    case object_type
    when '__sprint'
      RbSprint
    when '__release'
      RbRelease
    when '__team'
      Group
    when '__state'
      IssueStatus
    else #assume an id of tracker, see our options in helper
      RbGeneric
    end
  end

  def row_object(id)
    unless id > 0
      return nil
    end
    cls = resolve_class(row_type)
    cls.find(id)
  end

  def col_object(id)
    unless id > 0
      return nil
    end
    cls = resolve_class(col_type)
    cls.find(id)
  end

  def type_name(object_type)
    case object_type
    when '__sprint'
      "Sprint"
    when '__release'
      "Release"
    when '__team'
      "Team"
    when '__state'
      "State"
    when '__parent'
      "Epic"
    else #assume an id of tracker, see our options in helper
      tracker_id = object_type
      tracker = Tracker.where(:id => tracker_id).take
      if tracker
        tracker.name
      else
        "unknown"
      end
    end
  end

  def element_type_name
    type_name(element_type)
  end

  def row_type_name
    type_name(row_type)
  end

  def col_type_name
    type_name(col_type)
  end

  def prefilter_name
    if prefilter.blank?
      return ''
    end
    filter = prefilter
    filter = [filter] if filter && !filter.is_a?(Array)
    filter.collect { |f| filter_name(f, nil) }.compact.join(' and ')
  end

  def filter_name(f, default="")
    case f
    when '__current_release'
      "Current Release"
    when '__current_or_no_release'
      "Current or no Release"
    when '__current_sprint'
      "Current Sprint"
    when '__current_or_no_sprint'
      "Current or no Sprint"
    when '__my_team'
      "my Team"
    when '__parent'
      "Epic"
    else
      default
    end
  end

  def prefilter_objects(project, filteroptions={})
    filter_objects(project, prefilter, filteroptions)
  end
  def filter_objects(project, filter, filteroptions={})
    if filter.nil?
      return {}
    end
    filter = [filter] if filter && !filter.is_a?(Array)

    Hash[filter.zip(filter.collect{|f| find_filter_object(project, f, filteroptions)})]
  end

  def filter_object_ids(project, filter, filteroptions)
    if filter.nil?
      return {}
    end
    filter = [filter] if filter && !filter.is_a?(Array)

    Hash[filter.zip(filter.collect{|f| find_filter_object_id(project, f, filteroptions)})]
  end

  def prefilter_alternative_options(project, filteroptions)
    filter_alternative_options(project, prefilter, filteroptions)
  end

  def rowfilter_alternative_options(project, filteroptions)
    if rowfilter.include? '__parent'
      filter_alternative_options(project, ['__parent'], filteroptions)
    else # do not offer current release or stuff filters for rows here
      []
    end
  end

  def filter_alternative_options(project, filter, filteroptions)
    filter = [filter] if filter && !filter.is_a?(Array)
    # assemble objects into __filter => list
    opts = Hash[filter.collect{|f|
      [f, {:values=>find_filter_alternative_options(project, f)}] unless f.blank?
    }.compact()]
    # convert onbjects in lists to [id, name] tuples
    opts.each {|key, optionlist|
      unless optionlist.blank?
        optionlist[:values].collect!{|o| [o.respond_to?(:subject) ? o.subject : o.name, o.id] unless o.blank?}.compact()
        optionlist[:values] << [ 'None', -1]
        optionlist[:values] << [ 'Any', 0]

        fo = find_filter_object(project, key, filteroptions)
        if fo
          if fo.is_a? Integer
            optionlist[:selected] = fo
          else
            optionlist[:selected] = (fo && fo.id) || 0
          end
        end
        optionlist[:label] = filter_name(key)
        optionlist[:key] = find_filter_option_key(key)
      end
    }
    opts
  end

  def columns(project, options={})
    if col_type != element_type #elements by col_type
      c = resolve_scope(col_type, project, colfilter, options)
      if include_none_in_cols?
        c = c.to_a.unshift(RbFakeGeneric.new("No #{col_type_name}"))
      end
      return c
    else #one column for the elements
      return [ RbFakeGeneric.new("#{col_type_name}") ]
    end
  end

  def rows(project, options={})
    c = resolve_scope(row_type, project, rowfilter, options)
    if include_none_in_rows?
      c.to_a.append(RbFakeGeneric.new("No #{row_type_name}"))
    end
    c
  end

  def elements(project, options={})
    #it will do no harm when we got the '__parents' filter set in options, it will not be used when it is not in prefilter.
    e = resolve_scope(element_type, project, prefilter, options)

    # when we have an issue as parent, we don't need to query all elements, we restrict to visible rows
    parent_attribute = resolve_parent_attribute(row_type)
    if parent_attribute == :parent
      #Rails.logger.info('XXXXXXX injecting parent relation for elements')
      row_ids = rows(project, options).to_a.collect{|f| f.id}.to_a
      #Rails.logger.info("xxxxxxxrows #{row_ids}")
      if include_none_in_rows?
        e = e.where(["(#{RbGeneric.table_name}.parent_id in (?) or #{RbGeneric.table_name}.parent_id is null)", row_ids])
      else
        e = e.where(:parent_id => row_ids)
      end
      #Rails.logger.info("xxxxxelements #{e.to_a.collect{|f| f.id}}")
    end
    e
  end

  def elements_by_cell(project, options={})
    parent_attribute = resolve_parent_attribute(row_type)
    if col_type != element_type
      column_attribute = resolve_parent_attribute(col_type)
    else
      column_attribute = nil
      col_id = 0
    end

    @used_rows = {}
    #aggregate all elements in scope into a matrix indexed by row/column object ids
    map = {}
    elements(project, options).each {|element|
      row_id = element.send(parent_attribute)
      unless row_id.nil?
        row_id = row_id.id
      else
        row_id = 0
      end

      unless column_attribute.nil?
        col_id = element.send(column_attribute)
        unless col_id.nil?
          col_id = col_id.id
        else
          col_id = 0
        end
      end
      unless map.include? row_id
        map[row_id] = {}
      end
      unless map[row_id].include? col_id
        map[row_id][col_id] = []
      end
      map[row_id][col_id].append(element)
      @used_rows[row_id] = true
    }

    map
  end

  def row_used?(row_id)
    @used_rows.include? row_id
  end

  def include_none_in_rows?
    self.boardoptions['include_none_in_rows'] == "1"
  end
  def include_none_in_rows
    self.boardoptions['include_none_in_rows']
  end
  def include_none_in_rows=(val)
    self.boardoptions['include_none_in_rows'] = val
  end
  def include_none_in_cols?
    self.boardoptions['include_none_in_cols'] == "1"
  end
  def include_none_in_cols
    self.boardoptions['include_none_in_cols']
  end
  def include_none_in_cols=(val)
    self.boardoptions['include_none_in_cols'] = val
  end
  def include_closed_elements?
    self.boardoptions['include_closed_elements'] == "1"
  end
  def include_closed_elements
    self.boardoptions['include_closed_elements']
  end
  def include_closed_elements=(val)
    self.boardoptions['include_closed_elements'] = val
  end
  def immutable_positions?
    self.boardoptions['immutable_positions'] == "1"
  end
  def immutable_positions
    self.boardoptions['immutable_positions']
  end
  def immutable_positions=(val)
    self.boardoptions['immutable_positions'] = val
  end
  def hide_empty_rows?
    self.boardoptions['hide_empty_rows'] == "1"
  end
  def hide_empty_rows
    self.boardoptions['hide_empty_rows']
  end
  def hide_empty_rows=(val)
    self.boardoptions['hide_empty_rows'] = val
  end

end
