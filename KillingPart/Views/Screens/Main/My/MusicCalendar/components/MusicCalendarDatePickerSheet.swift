import SwiftUI

struct MusicCalendarDatePickerSheet: View {
    @Binding var pickerYear: Int
    @Binding var pickerMonth: Int
    let yearOptions: [Int]
    let onCancel: () -> Void
    let onDone: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Button("취소", action: onCancel)
                    .font(AppFont.paperlogy5Medium(size: 14))
                    .foregroundStyle(.white.opacity(0.78))

                Spacer(minLength: 0)

                Button("완료", action: onDone)
                    .font(AppFont.paperlogy6SemiBold(size: 14))
                    .foregroundStyle(AppColors.primary600)
            }
            .padding(.horizontal, AppSpacing.l)
            .padding(.top, AppSpacing.m)

            HStack(spacing: 0) {
                Picker("년도", selection: $pickerYear) {
                    ForEach(yearOptions, id: \.self) { year in
                        Text(verbatim: "\(year)년")
                            .tag(year)
                    }
                }
                .pickerStyle(.wheel)
                .labelsHidden()

                Picker("월", selection: $pickerMonth) {
                    ForEach(1...12, id: \.self) { month in
                        Text(verbatim: "\(month)월")
                            .tag(month)
                    }
                }
                .pickerStyle(.wheel)
                .labelsHidden()
            }
            .frame(height: 220)
            .padding(.horizontal, AppSpacing.m)
            .padding(.bottom, AppSpacing.m)
        }
        .presentationDetents([.height(320)])
        .presentationDragIndicator(.visible)
    }
}
