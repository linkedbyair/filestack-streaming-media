class AudiosController < ApplicationController
  # Actions
  #########

  def index
    @record = Audio.last
    redirect_to action: :new if @record.blank?
  end
  
  def new
    @record = Audio.new
  end

  def create
    redirect_to action: :new if permitted_params[:audio_url].blank?
    
    @record = Audio.new
    file = client.store(permitted_params[:audio_url])
    @record.audio_url = file.url
    if @record.save
      redirect_to action: :index, notice: 'Audio was successfully created. Please wait a few minutes for the audio to be processed.'
    else
      render action: 'new'
    end
  rescue Filepicker::ClientError => e
    redirect_to action: :new, alert: e.message
  end

  def edit
    @record = Audio.find(params[:id])
  end

  def update
    redirect_to action: :edit if permitted_params[:audio_url].blank?

    @record = Audio.find(params[:id])
    file = client.store(permitted_params[:audio_url])
    if @record.update(audio_url: file.url)
      redirect_to action: :index, notice: 'Audio was successfully updated.'
    else
      render action: 'edit'
    end
  rescue Filepicker::ClientError => e
    redirect_to action: :edit, alert: e.message
  end

  private

  def permitted_params
    params.permit(:audio_url)
  end

  def client
    @client ||= Filepicker::Client.new
  end
end