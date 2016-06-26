require 'sinatra'
require 'sinatra/reloader'
require 'tilt/erubis'
require 'date'
require 'yaml'
require 'bcrypt'
require 'pry'

configure do
  enable :sessions
  set :session_secret, 'secret'
end

before do
  @week = { 1 => 'Monday',
            2 => 'Tuesday',
            3 => 'Wednesday',
            4 => 'Thursday',
            5 => 'Friday',
            6 => 'Saturday',
            0 => 'Sunday' }
  session[:identity] ||= []
  session[:food] ||= {}
  session[:the_first_monday] ||= Date.today + (1 - Date.today.wday)
  @users = YAML.load_file('users.yaml')
end

helpers do
  def get_monday_date(id)
    session[:the_first_monday] + (7 * id)
  end

  def today_id
    date = Date.today
    ((date + (1 - date.wday) - get_monday_date(0)) / 7).to_i
  end

  def sign_in?
    session.key?(:user)
  end

  def set_up?
    session[:baby] && session[:food][0]
  end

  def ensure_sign_in
    unless sign_in?
      session[:message] = 'You must sign in to do that.'
      redirect '/signin'
    end
  end

  def ensure_set_up
    unless set_up?
      session[:message] = 'You must set up the page to view that'
      redirect '/setup'
    end
  end

  def baby_name
    if session[:baby].nil? || session[:baby].strip.empty?
      'your baby'
    else
      session[:baby]
    end
  end

  # def add_week_on_monday
  #   session[:identity] << session[:identity].last + 1 if Date.today.wday == 1
  # end
end

get '/' do
  if !session[:user]
    redirect '/signin'
  elsif !session[:food][0]
    redirect '/setup'
  else
    redirect '/overview'
  end
end

get '/setup' do
  ensure_sign_in
  if session[:food][0]
    redirect '/overview'
  else
    erb :setup
  end
end

post '/setup' do
  ensure_sign_in
  session[:baby] = params[:baby_name]

  if session[:baby].strip.empty?
    session[:message] = 'Please put in a valid name'
    erb :setup
  else
    session[:food][0] = {}
    redirect '/question/0'
  end
end

get '/signup' do
  erb :signup
end

post '/signup' do
  username = params[:username]
  password = params[:password]

  if username.strip.empty?
    session[:message] = 'Username can not be empty'
    erb :signup
  elsif password.size < 6
    session[:message] = 'Password must be at least 6 characters long'
    erb :signup
  elsif password.scan(/\d/).empty?
    session[:message] = 'password must contain at least one number'
    erb :signup
  else
    @users[username] = BCrypt::Password.create(password)
    File.open('users.yaml', 'w') { |file| file.write @users.to_yaml }
    session[:message] = 'You have successfully signed up'
    redirect '/signin'
  end
end

get '/signin' do
  erb :signin
end

post '/signin' do
  username = params[:username]
  password = params[:password]
  if @users.key?(username) && BCrypt::Password.new(@users[username]) == password
    session[:user] = username
    redirect '/setup'
  else
    session[:message] = 'Sign in is failed'
    erb :signin
  end
end

post '/signout' do
  session.delete(:user)
  session[:message] = 'You have been signed out.'
  redirect '/signin'
end

get '/overview' do
  ensure_sign_in
  ensure_set_up
  erb :overview
end

get '/question/:id' do
  ensure_sign_in
  ensure_set_up
  @id = params[:id].to_i
  erb :question
end

post '/question/:id' do
  ensure_sign_in
  ensure_set_up
  @id = params[:id].to_i
  unless @week.all? do |_, week|
    params[week.to_sym].empty?
  end
    session[:identity] << @id unless session[:identity].include?(@id)
    session[:food][@id] = {}

    @week.each do |_, week|
      session[:food][@id][week] = params[week.to_sym]
    end
    session[:message] = 'The food has been saved'
  end
  redirect "/question/#{@id}"
end
