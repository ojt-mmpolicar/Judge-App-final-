class Contestant {
  final String name;
  final int age;
  final Map<String, List<String>> judges; // {eventName: [judge1, judge2]}

  Contestant({
    required this.name,
    required this.age,
    required this.judges,
  });

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'age': age,
      'judges': judges,
    };
  }

  static Contestant fromMap(Map<String, dynamic> map) {
    return Contestant(
      name: map['name'],
      age: map['age'],
      judges: Map<String, List<String>>.from(map['judges']),
    );
  }
}
