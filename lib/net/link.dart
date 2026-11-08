/// Транспорт, через который клиент общается с игровым сервером.
abstract class GameLink {
  Stream<Map<String, dynamic>> get messages;

  void send(Map<String, dynamic> message);

  Future<void> close();
}
