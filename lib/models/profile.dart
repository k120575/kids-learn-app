/// 一個孩子的檔案。多個孩子共用一台平板時，星星/貼紙/紀錄各自獨立。
class Profile {
  const Profile({
    required this.id,
    required this.name,
    required this.emoji,
    this.createdAt = 0,
    this.sort = 0,
  });

  final String id;
  final String name;
  final String emoji;
  final int createdAt;
  final int sort;

  Profile copyWith({String? name, String? emoji}) => Profile(
    id: id,
    name: name ?? this.name,
    emoji: emoji ?? this.emoji,
    createdAt: createdAt,
    sort: sort,
  );
}
