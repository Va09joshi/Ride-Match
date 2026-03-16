class CarDetails {
  final String name;
  final String number;
  final String color;

  CarDetails({
    required this.name,
    required this.number,
    required this.color,
  });

  factory CarDetails.fromJson(Map<String, dynamic> json) {
    return CarDetails(
      name: json['name'] ?? '',
      number: json['number'] ?? '',
      color: json['color'] ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'number': number,
      'color': color,
    };
  }
}
