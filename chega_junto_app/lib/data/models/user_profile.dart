class UserProfile {
  const UserProfile({
    required this.fullName,
    required this.email,
    required this.phone,
    required this.susCardNumber,
    this.birthDate = '',
    this.cpf = '',
    this.postcode = '',
    this.street = '',
    this.number = '',
    this.complement = '',
    this.neighborhood = '',
    this.city = '',
    this.emergencyName = '',
    this.emergencyRelationship = '',
    this.emergencyPhone = '',
  });
  final String fullName;
  final String email;
  final String phone;
  final String susCardNumber;
  final String birthDate,
      cpf,
      postcode,
      street,
      number,
      complement,
      neighborhood,
      city;
  final String emergencyName, emergencyRelationship, emergencyPhone;

  UserProfile copyWith({
    String? fullName,
    String? email,
    String? phone,
    String? birthDate,
    String? cpf,
    String? postcode,
    String? street,
    String? number,
    String? complement,
    String? neighborhood,
    String? city,
    String? emergencyName,
    String? emergencyRelationship,
    String? emergencyPhone,
  }) => UserProfile(
    fullName: fullName ?? this.fullName,
    email: email ?? this.email,
    phone: phone ?? this.phone,
    susCardNumber: susCardNumber,
    birthDate: birthDate ?? this.birthDate,
    cpf: cpf ?? this.cpf,
    postcode: postcode ?? this.postcode,
    street: street ?? this.street,
    number: number ?? this.number,
    complement: complement ?? this.complement,
    neighborhood: neighborhood ?? this.neighborhood,
    city: city ?? this.city,
    emergencyName: emergencyName ?? this.emergencyName,
    emergencyRelationship: emergencyRelationship ?? this.emergencyRelationship,
    emergencyPhone: emergencyPhone ?? this.emergencyPhone,
  );
}
