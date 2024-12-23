require 'prawn'

include RbCommonHelper

class RbEpicsController < RbApplicationController
  unloadable
  include BacklogsPrintableCards

  def index
    if ! BacklogsPrintableCards::CardPageLayout.selected
      render plain: "No label stock selected. How did you get here?", :status => 500
      return
    end

    begin
      cards = BacklogsPrintableCards::PrintableCards.new(params[:sprint_id] ? @sprint.epics : RbEpic.product_backlog(@project), params[:sprint_id], current_language)
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
      epic = RbEpic.create_and_position(params)
    rescue => e
      render plain: e.message.blank? ? e.to_s : e.message, :status => 400
      return
    end

    status = (epic.id ? 200 : 400)

    if params[:view] == "epic_eb"
      respond_to do |format|
        format.html { render :partial => "epic_eb", :collection => [epic], :as => :epic }
      end
    else
      respond_to do |format|
        format.html { render :partial => "epic", :object => epic, :status => status }
      end
    end
  end

  def update
    epic = RbEpic.find(params[:id])
    begin
      result = epic.update_and_position!(params)
    rescue => e
      render plain: e.message.blank? ? e.to_s : e.message, :status => 400
      return
    end

    status = (result ? 200 : 400)

    if params[:view] == "epic_eb"
      respond_to do |format|
        format.html { render :partial => "epic_eb", :collection => [epic], :as => :epic }
      end
    else
      respond_to do |format|
        format.html { render :partial => "epic", :object => epic, :status => status }
      end
    end
  end

  def tooltip
    epic = RbEpic.find(params[:id])
    respond_to do |format|
      format.html { render :partial => "tooltip", :object => epic }
    end
  end

end
