require './models'

server_list = ['1.example.com:8387', '2.example.com:8387']
server_list.each do |s|
  Server.create(server_name: s)
end

