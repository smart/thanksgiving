class ThanksController < ApplicationController
  
  make_resourceful do
    actions :all
    
    #response_for :create do |format|
    #  format.html { redirect_to(objects_path) }
    #end
    
    #response_for :delete do |format|
    #  format.html { redirect_to(objects_path) }
    #end
    
  end
end
