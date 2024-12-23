require 'prawn'

include RbCommonHelper

class RbStoriesController < RbApplicationController
  unloadable
  include BacklogsPrintableCards

  def index
    if ! BacklogsPrintableCards::CardPageLayout.selected
      render plain: "No label stock selected. How did you get here?", :status => 500
      return
    end

    begin
      cards = BacklogsPrintableCards::PrintableCards.new(params[:sprint_id] ? @sprint.stories : RbStory.product_backlog(@project), params[:sprint_id], current_language)
    rescue Prawn::Errors::CannotFit
      render plain: "There was a problem rendering the cards. A possible error could be that the selected font exceeds a render box", :status => 500
      return
    end

    respond_to do |format|
      format.pdf {
        send_data(cards.pdf.render, :disposition => 'attachment', :type => 'application/pdf')
      }
    end
  end

  def create
    params['author_id'] = User.current.id
    if params[:epic_tracker_id]
      params[:tracker_id] = params[:epic_tracker_id]
    end
    begin
      story = RbStory.create_and_position(params)
    rescue => e
      render plain: e.message.blank? ? e.to_s : e.message, :status => 400
      return
    end

    status = (story.id ? 200 : 400)

    if params[:view] == "story_eb"
      respond_to do |format|
        format.html { render :partial => "story_eb", :collection => [story], :as => :story }
      end
    else
      respond_to do |format|
        format.html { render :partial => "story", :object => story, :status => status }
      end
    end
  end

  def update
    story = RbStory.find(params[:id])
    if params[:view] == "taskboard"
      params.delete(:next)
    end
    
    #to be able to add story specific status_id change combo, the fieldname also contains the story-id
    params[:status_id] = params.delete("status_id_story_#{params[:id]}") if params.include?("status_id_story_#{params[:id]}")

    begin
      result = story.update_and_position!(params)
    rescue => e
      render plain: e.message.blank? ? e.to_s : e.message, :status => 400
      return
    end

    status = (result ? 200 : 400)

    @roles = User.current.admin ? Role.all : User.current.roles_for_project(@project)

    if params[:view] == "taskboard"
      respond_to do |format|
        format.html { render :partial => "story_tb", :collection => [story], :as => :story }
      end
    elsif params[:view] == "story_eb"
      respond_to do |format|
        format.html { render :partial => "story_eb", :collection => [story], :as => :story }
      end
    else
      respond_to do |format|
        format.html { render :partial => "story", :object => story, :status => status }
      end
    end
  end

  def tooltip
    story = RbStory.find(params[:id])
    respond_to do |format|
      format.html { render :partial => "tooltip", :object => story }
    end
  end

end
